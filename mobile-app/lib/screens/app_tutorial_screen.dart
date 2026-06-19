import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';

class AppTutorialScreen extends StatefulWidget {
  const AppTutorialScreen({super.key});

  @override
  State<AppTutorialScreen> createState() => _AppTutorialScreenState();
}

class _AppTutorialScreenState extends State<AppTutorialScreen> {
  int _activeStep = 0;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final steps = [
      (
        Icons.camera_alt_outlined,
        'scan',
        lang.t('tutorial.step1Title'),
        lang.t('tutorial.step1'),
        const Color(0xFFDCFCE7),
        AppColors.primary,
      ),
      (
        Icons.check_circle_outline,
        'result',
        lang.t('tutorial.step2Title'),
        lang.t('tutorial.step2'),
        const Color(0xFFDBEAFE),
        const Color(0xFF2563EB),
      ),
      (
        Icons.location_on_outlined,
        'field',
        lang.t('tutorial.step3Title'),
        lang.t('tutorial.step3'),
        const Color(0xFFF3E8FF),
        const Color(0xFF7C3AED),
      ),
      (
        Icons.bar_chart_outlined,
        'report',
        lang.t('tutorial.step5Title'),
        lang.t('tutorial.step5'),
        const Color(0xFFFCE7F3),
        const Color(0xFFDB2777),
      ),
      (
        Icons.chat_outlined,
        'bot',
        lang.t('tutorial.step6Title'),
        lang.t('tutorial.step6'),
        const Color(0xFFCCFBF1),
        const Color(0xFF0D9488),
      ),
    ];
    final current = steps[_activeStep];

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.t('tutorial.title'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        lang.t('tutorial.subtitle'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.eco_rounded,
                            size: 48,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              lang.isRTL
                                  ? 'اتبع الخطوات التالية للانتقال من الفحص إلى التقارير بسهولة.'
                                  : 'Follow these steps to move smoothly from scanning to reports.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: List.generate(steps.length, (index) {
                        final isActive = index == _activeStep;
                        final isDone = index < _activeStep;
                        return Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _activeStep = index),
                                  child: Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.primary
                                          : isDone
                                          ? const Color(0xFFBBF7D0)
                                          : const Color(0xFFE5E7EB),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: isActive
                                              ? Colors.white
                                              : AppColors.primaryDark,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (index < steps.length - 1)
                                Expanded(
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? const Color(0xFFBBF7D0)
                                          : const Color(0xFFE5E7EB),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: current.$5,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              current.$1,
                              size: 40,
                              color: current.$6,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            current.$3,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            current.$4,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6B7280),
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_activeStep > 0) ...[
                                OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _activeStep--),
                                  // Override global theme: buttons in a Row must
                                  // not have minimumSize=double.infinity (full-width),
                                  // or they crash when the Row has unbounded width.
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(88, 48),
                                  ),
                                  child: Text(lang.t('common.back')),
                                ),
                                const SizedBox(width: 12),
                              ],
                              ElevatedButton(
                                onPressed: _activeStep < steps.length - 1
                                    ? () => setState(() => _activeStep++)
                                    : () => context.go('/home'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  // Same override: content-sized, not full-width.
                                  minimumSize: const Size(88, 48),
                                ),
                                child: Text(
                                  _activeStep < steps.length - 1
                                      ? lang.t('common.next')
                                      : lang.t('common.done'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(steps.length, (index) {
                        final step = steps[index];
                        final isActive = index == _activeStep;
                        return GestureDetector(
                          onTap: () => setState(() => _activeStep = index),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: step.$5,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    step.$1,
                                    size: 16,
                                    color: step.$6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        step.$3,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        step.$4,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFEE2E2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    size: 20,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  lang.t('tutorial.watchVideo'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeStep = 0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFDCFCE7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.replay,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    lang.t('tutorial.restart'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
