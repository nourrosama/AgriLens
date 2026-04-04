import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(
                          Icons.arrow_back,
                          size: 28,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    lang.t('subscription.title'),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _planCard(
                      context,
                      lang,
                      lang.t('subscription.free'),
                      '\$0',
                      [
                        lang.isRTL ? '5 فحوصات يومياً' : '5 scans/day',
                        lang.isRTL
                            ? 'كشف أمراض أساسي'
                            : 'Basic disease detection',
                        lang.isRTL ? 'حقل واحد' : '1 field',
                      ],
                      false,
                    ),
                    const SizedBox(height: 16),
                    _planCard(
                      context,
                      lang,
                      lang.t('subscription.pro'),
                      '\$9.99',
                      [
                        lang.isRTL ? 'فحوصات غير محدودة' : 'Unlimited scans',
                        lang.isRTL ? 'تحليل متقدم' : 'Advanced analysis',
                        lang.isRTL ? 'حتى 10 حقول' : 'Up to 10 fields',
                        lang.isRTL ? 'توقعات الأمراض' : 'Disease forecasting',
                        lang.isRTL ? 'تقارير PDF' : 'PDF reports',
                      ],
                      true,
                    ),
                    const SizedBox(height: 16),
                    _planCard(
                      context,
                      lang,
                      lang.t('subscription.enterprise'),
                      '\$29.99',
                      [
                        lang.isRTL ? 'كل ميزات برو' : 'All Pro features',
                        lang.isRTL ? 'حقول غير محدودة' : 'Unlimited fields',
                        lang.isRTL ? 'دعم أولوية' : 'Priority support',
                        lang.isRTL ? 'API مخصص' : 'Custom API access',
                        lang.isRTL ? 'تحليلات متقدمة' : 'Advanced analytics',
                      ],
                      false,
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

  Widget _planCard(
    BuildContext ctx,
    LanguageProvider lang,
    String name,
    String price,
    List<String> features,
    bool recommended,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: recommended ? AppColors.primary : AppColors.border,
          width: recommended ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recommended) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                lang.isRTL ? 'موصى به' : 'Recommended',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            name,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                lang.t('subscription.month'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => ctx.push('/subscription-payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: recommended ? AppColors.primary : Colors.white,
                foregroundColor: recommended ? Colors.white : AppColors.primary,
                side: recommended
                    ? null
                    : const BorderSide(color: AppColors.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                lang.isRTL ? 'اختر الخطة' : 'Choose Plan',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
