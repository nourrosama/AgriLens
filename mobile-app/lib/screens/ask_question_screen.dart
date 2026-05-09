import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

class AskQuestionScreen extends StatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  State<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends State<AskQuestionScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _cropTagCtrl = TextEditingController();
  final _diseaseTagCtrl = TextEditingController();
  final List<String> _cropTags = [];
  final List<String> _diseaseTags = [];
  bool _submitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _cropTagCtrl.dispose();
    _diseaseTagCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    setState(() => _submitting = true);

    final question = await context.read<ForumProvider>().askQuestion(
      title: title,
      body: body,
      cropTags: _cropTags,
      diseaseTags: _diseaseTags,
    );

    if (mounted) {
      setState(() => _submitting = false);
      if (question != null) {
        context.pop();
        // Navigate to the newly created question
        context.push('/question/${question.id}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageProvider>().isRTL
                  ? 'فشل نشر السؤال. حاول مرة أخرى.'
                  : 'Failed to post question. Please try again.',
            ),
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

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRTL ? 'اطرح سؤالاً' : 'Ask a Question',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_submitting)
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
            // Helper banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.primaryDark,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRTL
                          ? 'كن محدداً: صِف المحصول والأعراض وما جربته حتى الآن.'
                          : 'Be specific: describe your crop, symptoms, and what you\'ve tried.',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Title
            _FieldLabel(isRTL ? 'عنوان السؤال *' : 'Question title *'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              maxLength: 120,
              decoration: InputDecoration(
                hintText: isRTL
                    ? 'مثال: لماذا تتحول أوراق الطماطم إلى صفراء؟'
                    : 'e.g. Why are my tomato leaves turning yellow?',
                counterStyle: const TextStyle(fontSize: 11),
              ),
            ),

            const SizedBox(height: 16),

            // Body
            _FieldLabel(isRTL ? 'وصف تفصيلي *' : 'Detailed description *'),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyCtrl,
              minLines: 5,
              maxLines: 14,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                hintText: isRTL
                    ? 'اشرح المشكلة بالتفصيل: متى بدأت؟ ما نسبة الإصابة؟ ما التربة والمناخ؟'
                    : 'Describe the problem in detail: when did it start? What percentage of plants are affected? Soil type, climate?',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 20),

            // Crop tags
            _TagSection(
              title: isRTL ? 'المحاصيل المرتبطة' : 'Related crops',
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
              title: isRTL ? 'الأمراض المشتبه بها' : 'Suspected diseases',
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
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
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
        _FieldLabel(title),
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
