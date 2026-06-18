"""
Grad-CAM implementation for timm EfficientNet models.

GradCAM hooks are registered once at model-load time (via model_loader.py)
and re-used across requests — never create a GradCAM inside a request handler.
"""
from __future__ import annotations

import base64
import io
import logging

import matplotlib.cm as mpl_cm
import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image

logger = logging.getLogger(__name__)


def _get_target_layer(model: torch.nn.Module) -> torch.nn.Module:
    """
    Return the best Grad-CAM target layer for a timm EfficientNet model.

    For timm EfficientNet variants the last convolutional layer before global
    average pooling is ``model.conv_head`` (a pointwise Conv2d that produces
    the feature map we want to visualise).  If that attribute is absent we fall
    back to the last sub-block of the last block stage.
    """
    if hasattr(model, 'conv_head'):
        return model.conv_head

    # Fallback: last sub-block of the last block stage
    if hasattr(model, 'blocks') and len(model.blocks) > 0:
        last_stage = model.blocks[-1]
        sub_blocks = list(last_stage.children())
        if sub_blocks:
            return sub_blocks[-1]
        return last_stage

    if hasattr(model, 'features'):
        conv_layers = [
            module
            for module in model.features.modules()
            if isinstance(module, torch.nn.Conv2d)
        ]
        if conv_layers:
            return conv_layers[-1]

    raise RuntimeError(
        'Could not locate a suitable Grad-CAM target layer in this model. '
        'Expected model.conv_head, model.blocks[-1][-1], or convolutional features.'
    )


class GradCAM:
    """
    Gradient-weighted Class Activation Mapping.

    Hooks are registered once in __init__.  The same object is shared across
    all requests for a given crop model — this is safe because generate()
    is called synchronously (no concurrent requests in the same worker).
    """

    def __init__(self, model: torch.nn.Module, target_layer: torch.nn.Module) -> None:
        self.model = model
        self.gradients: torch.Tensor | None = None
        self.activations: torch.Tensor | None = None
        self._hooks: list = []
        self._register_hooks(target_layer)

    # ------------------------------------------------------------------
    # Hook registration
    # ------------------------------------------------------------------

    def _register_hooks(self, target_layer: torch.nn.Module) -> None:
        def _fwd(_, __, output: torch.Tensor) -> None:
            self.activations = output.detach()

        def _bwd(_, __, grad_output: tuple[torch.Tensor]) -> None:
            self.gradients = grad_output[0].detach()

        h_fwd = target_layer.register_forward_hook(_fwd)
        h_bwd = target_layer.register_full_backward_hook(_bwd)
        self._hooks = [h_fwd, h_bwd]

    def remove_hooks(self) -> None:
        """Clean up hooks (call only when discarding the GradCAM object)."""
        for h in self._hooks:
            h.remove()
        self._hooks = []

    # ------------------------------------------------------------------
    # CAM generation
    # ------------------------------------------------------------------

    def generate(
        self,
        input_tensor: torch.Tensor,
        class_idx: int | None = None,
        output_size: tuple[int, int] | None = None,
    ) -> np.ndarray:
        """
        Run a forward+backward pass and return a (H, W) CAM in [0, 1].

        Parameters
        ----------
        input_tensor:
            Shape (1, C, H, W), already on the correct device, *with*
            ``requires_grad=True``.  Must be called inside
            ``torch.enable_grad()``.
        class_idx:
            Target class index.  If None, uses the predicted class.
        output_size:
            (height, width) to resize the CAM to.  Defaults to the spatial
            size of *input_tensor*.
        """
        self.model.eval()
        output = self.model(input_tensor)

        if class_idx is None:
            class_idx = int(output.argmax(dim=1).item())

        self.model.zero_grad()
        one_hot = torch.zeros_like(output)
        one_hot[0, class_idx] = 1.0
        output.backward(gradient=one_hot)

        if self.gradients is None or self.activations is None:
            raise RuntimeError(
                'Grad-CAM hooks did not fire — check that the target layer is '
                'part of the forward graph.'
            )

        # Global average pooling of gradients → channel weights
        weights = self.gradients.mean(dim=(2, 3), keepdim=True)  # (1, C, 1, 1)
        cam = (weights * self.activations).sum(dim=1, keepdim=True)  # (1, 1, h, w)
        cam = F.relu(cam)

        # Resize to input spatial resolution (or caller-requested size)
        h, w = output_size or (input_tensor.shape[-2], input_tensor.shape[-1])
        cam = F.interpolate(cam, size=(h, w), mode='bilinear', align_corners=False)
        cam = cam.squeeze().cpu().numpy()  # (H, W)

        # Normalise to [0, 1]
        cam = (cam - cam.min()) / (cam.max() - cam.min() + 1e-8)
        return cam


# ---------------------------------------------------------------------------
# Overlay helper
# ---------------------------------------------------------------------------

def generate_overlay_base64(original_img_np: np.ndarray, cam: np.ndarray) -> str:
    """
    Blend the original image with a jet-coloured Grad-CAM heatmap.

    Parameters
    ----------
    original_img_np:
        RGB image as float32 numpy array, shape (H, W, 3), values in [0, 1].
    cam:
        Grad-CAM array, shape (H, W), values in [0, 1].

    Returns
    -------
    Base64-encoded PNG string — safe to embed directly in JSON as
    ``"data:image/png;base64,<value>"`` or pass as the raw string and let
    the client prepend the data URI prefix.
    """
    heatmap = mpl_cm.jet(cam)[:, :, :3]                         # (H, W, 3) float
    overlay = (0.5 * original_img_np + 0.5 * heatmap).clip(0, 1)
    overlay_uint8 = (overlay * 255).astype(np.uint8)

    pil_img = Image.fromarray(overlay_uint8)
    buf = io.BytesIO()
    pil_img.save(buf, format='PNG', optimize=True)
    return base64.b64encode(buf.getvalue()).decode('utf-8')
