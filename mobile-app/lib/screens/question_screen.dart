import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key, required this.questionId});
  final String questionId;

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  ForumQuestion? _question;
  List<ForumAnswer> _answers = [];
  bool _loading = true;
  final _answerCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result =
        await context.read<ForumProvider>().getQuestion(widget.questionId);
    if (mounted) {
      setState(() {
        _question = result.question;
        _answers = result.answers;
        _loading = false;
      });
    }
  }

  Future<void> _sendAnswer() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final answer = await context
        .read<ForumProvider>()
        .postAnswer(widget.questionId, text);
    if (mounted && answer != null) {
      _answerCtrl.clear();
      setState(() {
        _answers = [..._answers, answer];
        _sending = false;
      });
    } else {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRTL = lang.isRTL;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isRTL ? 'سؤال وجواب' : 'Q&A Thread',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Question
                      if (_question != null) ...[
                        _QuestionHeader(question: _question!, isRTL: isRTL),
                        const SizedBox(height: 16),
                        Text(
                          isRTL
                              ? '${_question!.answerCount} إجابة'
                              : '${_question!.answerCount} answers',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Answers
                      if (_answers.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              isRTL
                                  ? 'كن أول من يجيب!'
                                  : 'Be the first to answer!',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final answer in _answers)
                          _AnswerTile(
                            answer: answer,
                            questionId: widget.questionId,
                            isQuestionAuthor:
                                _question?.authorId ==
                                answer.authorId, // simplified check
                            isRTL: isRTL,
                            onAccepted: () => setState(() {
                              for (final a in _answers) {
                                a.isAccepted = a.id == answer.id;
                              }
                            }),
                          ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),

                // Answer input
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _answerCtrl,
                          textDirection:
                              isRTL ? TextDirection.rtl : TextDirection.ltr,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText:
                                isRTL ? 'اكتب إجابتك...' : 'Write your answer…',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _sending
                          ? const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(
                                Icons.send_rounded,
                                color: AppColors.primary,
                              ),
                              onPressed: _sendAnswer,
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.question, required this.isRTL});
  final ForumQuestion question;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                if (question.isResolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isRTL ? 'تمت الإجابة' : 'Resolved',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(question.body, style: const TextStyle(fontSize: 14)),
            if (question.cropTags.isNotEmpty ||
                question.diseaseTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (final c in question.cropTags)
                    _SmallTag(label: c, color: AppColors.primary),
                  for (final d in question.diseaseTags)
                    _SmallTag(label: d, color: AppColors.warning),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.answer,
    required this.questionId,
    required this.isQuestionAuthor,
    required this.isRTL,
    required this.onAccepted,
  });

  final ForumAnswer answer;
  final String questionId;
  final bool isQuestionAuthor;
  final bool isRTL;
  final VoidCallback onAccepted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: answer.isAccepted
            ? AppColors.primaryLight
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: answer.isAccepted ? AppColors.primary : AppColors.border,
          width: answer.isAccepted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (answer.isAccepted)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isRTL ? 'إجابة مقبولة' : 'Accepted answer',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            Text(answer.body, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${answer.upvotes} ${isRTL ? "تصويت" : "votes"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (!answer.isAccepted)
                  TextButton.icon(
                    onPressed: () async {
                      final ok = await context
                          .read<ForumProvider>()
                          .acceptAnswer(answer.id, questionId);
                      if (ok) onAccepted();
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      isRTL ? 'قبول' : 'Accept',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#$label',
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}
