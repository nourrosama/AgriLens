import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _bodyCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  final _cropTagCtrl = TextEditingController();
  final _diseaseTagCtrl = TextEditingController();

  String _contentType = 'post';
  final List<String> _cropTags = [];
  final List<String> _diseaseTags = [];

  // Media state
  File? _pickedFile;
  String? _pickedFileName;
  bool _isVideo = false;
  bool _uploadingMedia = false;
  String? _uploadedMediaUrl; // set after successful upload

  bool _submitting = false;

  static const _types = ['post', 'video', 'article', 'blog'];

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _linkCtrl.dispose();
    _cropTagCtrl.dispose();
    _diseaseTagCtrl.dispose();
    super.dispose();
  }

  // ── Media picking ────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    if (kIsWeb) {
      _showWebMediaUnsupported();
      return;
    }
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return;
    setState(() {
      _pickedFile = File(xfile.path);
      _pickedFileName = xfile.name;
      _isVideo = false;
      _uploadedMediaUrl = null;
    });
    await _uploadPickedFile();
  }

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      _showWebMediaUnsupported();
      return;
    }
    final picker = ImagePicker();
    final xfile = await picker.pickVideo(source: ImageSource.gallery);
    if (xfile == null) return;
    setState(() {
      _pickedFile = File(xfile.path);
      _pickedFileName = xfile.name;
      _isVideo = true;
      _uploadedMediaUrl = null;
    });
    await _uploadPickedFile();
  }

  void _showWebMediaUnsupported() {
    final isRTL = context.read<LanguageProvider>().isRTL;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRTL
              ? 'رفع الملفات غير متاح على الويب. استخدم رابطاً خارجياً.'
              : 'File upload is not supported on web. Use an external link instead.',
        ),
      ),
    );
  }

  Future<void> _uploadPickedFile() async {
    if (_pickedFile == null) return;
    setState(() => _uploadingMedia = true);
    final url =
        await context.read<ForumProvider>().uploadMedia(_pickedFile!);
    if (mounted) {
      setState(() {
        _uploadedMediaUrl = url;
        _uploadingMedia = false;
      });
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageProvider>().isRTL
                  ? 'فشل رفع الملف. حاول مرة أخرى.'
                  : 'Upload failed. Please try again.',
            ),
          ),
        );
      }
    }
  }

  void _clearMedia() {
    setState(() {
      _pickedFile = null;
      _pickedFileName = null;
      _isVideo = false;
      _uploadedMediaUrl = null;
    });
  }

  // ── Submit ───────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final body = _bodyCtrl.text.trim();
    if (body.isEmpty) {
      final isRTL = context.read<LanguageProvider>().isRTL;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRTL
                ? 'الرجاء كتابة محتوى المنشور أولاً.'
                : 'Please write something before posting.',
          ),
        ),
      );
      return;
    }

    // If a file was picked but upload is still in progress, wait
    if (_uploadingMedia) return;

    // Decide on the media URL: prefer uploaded file, fall back to typed link
    final mediaUrl = _uploadedMediaUrl ?? _linkCtrl.text.trim();

    setState(() => _submitting = true);
    final post = await context.read<ForumProvider>().createPost(
      body: body,
      contentType: _contentType,
      mediaUrl: mediaUrl,
      cropTags: _cropTags,
      diseaseTags: _diseaseTags,
    );
    if (mounted) {
      setState(() => _submitting = false);
      if (post != null) {
        context.pop();
      } else {
        final isRTL = context.read<LanguageProvider>().isRTL;
        final errDetail = context.read<ForumProvider>().createPostError;
        final message = isRTL
            ? 'فشل النشر. حاول مرة أخرى.'
            : (errDetail != null
                ? 'Failed to post: $errDetail'
                : 'Failed to post. Please try again.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _addTag(TextEditingController ctrl, List<String> list) {
    final val = ctrl.text.trim().toLowerCase();
    if (val.isNotEmpty && !list.contains(val)) {
      setState(() => list.add(val));
    }
    ctrl.clear();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRTL ? 'إنشاء منشور' : 'Create Post',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_submitting || _uploadingMedia)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: Text(
                isRTL ? 'نشر' : 'Post',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content type selector
            _SectionLabel(isRTL ? 'نوع المحتوى' : 'Content type'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types.map((type) {
                final selected = _contentType == type;
                return ChoiceChip(
                  label: Text(_typeLabel(type, isRTL)),
                  selected: selected,
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _contentType = type),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Body
            _SectionLabel(isRTL ? 'المحتوى' : 'What do you want to share?'),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              minLines: 5,
              maxLines: 12,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                hintText: isRTL
                    ? 'شارك تجربتك أو نصيحتك أو مقالك...'
                    : 'Share your experience, tip, or article…',
              ),
            ),

            const SizedBox(height: 20),

            // ── Media section ────────────────────────────────────────────────
            _SectionLabel(
              isRTL ? 'وسائط (اختياري)' : 'Media (optional)',
            ),
            const SizedBox(height: 8),

            // File picker row
            if (_pickedFile == null) ...[
              Row(
                children: [
                  // Expanded gives each button a bounded width so
                  // OutlinedButton doesn't receive infinite constraints.
                  Expanded(
                    child: _MediaButton(
                      icon: Icons.image_rounded,
                      label: isRTL ? 'صورة' : 'Image',
                      onTap: _pickImage,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MediaButton(
                      icon: Icons.videocam_rounded,
                      label: isRTL ? 'فيديو' : 'Video',
                      onTap: _pickVideo,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // File preview card
              _FilePreviewCard(
                fileName: _pickedFileName ?? '',
                isVideo: _isVideo,
                isUploading: _uploadingMedia,
                uploadSuccess: _uploadedMediaUrl != null,
                onRemove: _clearMedia,
                isRTL: isRTL,
              ),
            ],

            const SizedBox(height: 16),

            // Link / URL field
            _SectionLabel(
              isRTL ? 'أو أضف رابطاً خارجياً' : 'Or add an external link',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _linkCtrl,
              keyboardType: TextInputType.url,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'https://',
                prefixIcon: const Icon(
                  Icons.link_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Crop tags
            _TagSection(
              title: isRTL ? 'المحاصيل المرتبطة' : 'Crop tags',
              hint: isRTL ? 'مثال: طماطم' : 'e.g. tomato',
              tags: _cropTags,
              controller: _cropTagCtrl,
              color: AppColors.primary,
              onAdd: () => _addTag(_cropTagCtrl, _cropTags),
              onRemove: (tag) => setState(() => _cropTags.remove(tag)),
            ),

            const SizedBox(height: 16),

            // Disease tags
            _TagSection(
              title: isRTL ? 'الأمراض المرتبطة' : 'Disease tags',
              hint: isRTL ? 'مثال: لفحة متأخرة' : 'e.g. late blight',
              tags: _diseaseTags,
              controller: _diseaseTagCtrl,
              color: AppColors.warning,
              onAdd: () => _addTag(_diseaseTagCtrl, _diseaseTags),
              onRemove: (tag) => setState(() => _diseaseTags.remove(tag)),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type, bool isRTL) {
    if (!isRTL) return type;
    const map = {
      'post': 'منشور',
      'video': 'فيديو',
      'article': 'مقال',
      'blog': 'مدونة',
    };
    return map[type] ?? type;
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  const _MediaButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

class _FilePreviewCard extends StatelessWidget {
  const _FilePreviewCard({
    required this.fileName,
    required this.isVideo,
    required this.isUploading,
    required this.uploadSuccess,
    required this.onRemove,
    required this.isRTL,
  });

  final String fileName;
  final bool isVideo;
  final bool isUploading;
  final bool uploadSuccess;
  final VoidCallback onRemove;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: uploadSuccess
              ? AppColors.primary
              : isUploading
                  ? AppColors.border
                  : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isVideo ? Icons.videocam_rounded : Icons.image_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                if (isUploading)
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isRTL ? 'جارٍ الرفع...' : 'Uploading…',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  )
                else if (uploadSuccess)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isRTL ? 'تم الرفع' : 'Uploaded',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    isRTL ? 'فشل الرفع' : 'Upload failed',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  const _TagSection({
    required this.title,
    required this.hint,
    required this.tags,
    required this.controller,
    required this.color,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String hint;
  final List<String> tags;
  final TextEditingController controller;
  final Color color;
  final VoidCallback onAdd;
  final void Function(String) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(title),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: hint),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle_rounded, color: color),
              onPressed: onAdd,
            ),
          ],
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: tags
                .map(
                  (tag) => Chip(
                    label: Text('#$tag'),
                    backgroundColor: color.withValues(alpha: 0.1),
                    labelStyle: TextStyle(color: color, fontSize: 12),
                    deleteIcon: Icon(Icons.close, size: 14, color: color),
                    onDeleted: () => onRemove(tag),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
