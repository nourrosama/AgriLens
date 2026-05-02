import os
import sys
import types


SERVICE_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if SERVICE_ROOT not in sys.path:
    sys.path.insert(0, SERVICE_ROOT)

if "cv2" not in sys.modules:
    cv2 = types.ModuleType("cv2")
    cv2.IMREAD_COLOR = 1
    cv2.COLOR_BGR2RGB = 1
    cv2.INTER_AREA = 1
    cv2.imdecode = lambda *args, **kwargs: None
    cv2.cvtColor = lambda image, code: image
    cv2.resize = lambda image, size, interpolation=None: image
    sys.modules["cv2"] = cv2

if "numpy" not in sys.modules:
    numpy = types.ModuleType("numpy")
    numpy.float32 = "float32"
    numpy.uint8 = "uint8"
    numpy.array = lambda value, dtype=None: value
    numpy.frombuffer = lambda value, dtype=None: value
    numpy.ndarray = object
    numpy.transpose = lambda value, axes: value
    sys.modules["numpy"] = numpy

if "timm" not in sys.modules:
    timm = types.ModuleType("timm")
    timm.create_model = lambda *args, **kwargs: None
    sys.modules["timm"] = timm

if "torch" not in sys.modules:
    torch = types.ModuleType("torch")

    class _Cuda:
        @staticmethod
        def is_available():
            return False

    class _NoGrad:
        def __enter__(self):
            return None

        def __exit__(self, exc_type, exc, tb):
            return False

    class _Module:
        pass

    class _Layer:
        def __init__(self, *args, **kwargs):
            pass

    torch.cuda = _Cuda()
    torch.nn = types.SimpleNamespace(
        Module=_Module,
        Dropout=_Layer,
        Linear=_Layer,
        ReLU=_Layer,
        Sequential=lambda *layers: list(layers),
    )
    torch.Tensor = object
    torch.device = lambda value: value
    torch.no_grad = _NoGrad
    torch.load = lambda *args, **kwargs: {}
    torch.from_numpy = lambda value: value
    torch.softmax = lambda outputs, dim=1: outputs
    torch.argmax = lambda values: 0
    torch.topk = lambda values, k: types.SimpleNamespace(indices=[], values=[])
    sys.modules["torch"] = torch

if "torchvision" not in sys.modules:
    torchvision = types.ModuleType("torchvision")
    models = types.ModuleType("torchvision.models")

    class _FakeVisionModel:
        classifier = None

    models.efficientnet_b3 = lambda weights=None: _FakeVisionModel()
    torchvision.models = models
    sys.modules["torchvision"] = torchvision
    sys.modules["torchvision.models"] = models
