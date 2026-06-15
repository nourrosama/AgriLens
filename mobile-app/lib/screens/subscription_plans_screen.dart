import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';

// Prices in Egyptian Pounds
const _plans = [
  {
    'key': 'free',
    'priceEgp': 0,
    'recommended': false,
  },
  {
    'key': 'pro',
    'priceEgp': 499,
    'recommended': true,
  },
  {
    'key': 'enterprise',
    'priceEgp': 1499,
    'recommended': false,
  },
];

class SubscriptionPlansScreen extends StatelessWidget {
  const SubscriptionPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final trialExpired = user.isTrialExpired;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  if (!trialExpired)
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
                  if (!trialExpired) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      trialExpired
                          ? lang.t('subscription.trialExpiredTitle')
                          : lang.t('subscription.choosePlan'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Trial expired banner
            if (trialExpired)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                color: const Color(0xFFFFF3E0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFFE65100), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.t('subscription.trialExpiredBody'),
                        style: const TextStyle(
                            color: Color(0xFFE65100), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Currency note
            Container(
              width: double.infinity,
              color: const Color(0xFFF0FDF4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined,
                      size: 16, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Text(
                    lang.isRTL
                        ? 'جميع الأسعار بالجنيه المصري (EGP)'
                        : 'All prices in Egyptian Pounds (EGP)',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
                      planKey: 'free',
                      name: lang.t('subscription.free'),
                      priceEgp: 0,
                      features: lang.isRTL
                          ? [
                              '5 فحوصات يومياً',
                              'كشف أمراض أساسي',
                              'حقل واحد',
                              'تقارير أساسية',
                            ]
                          : [
                              '5 scans / day',
                              'Basic disease detection',
                              '1 field',
                              'Basic reports',
                            ],
                      recommended: false,
                      isCurrent: user.plan == 'free',
                    ),
                    const SizedBox(height: 16),
                    _planCard(
                      context,
                      lang,
                      planKey: 'pro',
                      name: lang.t('subscription.pro'),
                      priceEgp: 499,
                      features: lang.isRTL
                          ? [
                              'فحوصات غير محدودة',
                              'تحليل متقدم للأمراض',
                              'حتى 10 حقول',
                              'توقعات الأمراض',
                              'تقارير PDF',
                              'دعم عبر الدردشة',
                            ]
                          : [
                              'Unlimited scans',
                              'Advanced disease analysis',
                              'Up to 10 fields',
                              'Disease forecasting',
                              'PDF reports',
                              'Chat support',
                            ],
                      recommended: true,
                      isCurrent: user.plan == 'pro',
                    ),
                    const SizedBox(height: 16),
                    _planCard(
                      context,
                      lang,
                      planKey: 'enterprise',
                      name: lang.t('subscription.enterprise'),
                      priceEgp: 1499,
                      features: lang.isRTL
                          ? [
                              'كل ميزات برو',
                              'حقول غير محدودة',
                              'دعم أولوية 24/7',
                              'وصول API مخصص',
                              'تحليلات متقدمة',
                              'مدير حساب مخصص',
                            ]
                          : [
                              'All Pro features',
                              'Unlimited fields',
                              'Priority 24/7 support',
                              'Custom API access',
                              'Advanced analytics',
                              'Dedicated account manager',
                            ],
                      recommended: false,
                      isCurrent: user.plan == 'enterprise',
                    ),
                    const SizedBox(height: 24),
                    // Guarantee note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined,
                              color: AppColors.primary, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang.isRTL
                                  ? 'ضمان استرداد المال خلال 7 أيام. يمكنك الإلغاء في أي وقت.'
                                  : '7-day money-back guarantee. Cancel anytime.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
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
    LanguageProvider lang, {
    required String planKey,
    required String name,
    required int priceEgp,
    required List<String> features,
    required bool recommended,
    required bool isCurrent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: recommended
              ? AppColors.primary
              : isCurrent
                  ? AppColors.primaryLight
                  : AppColors.border,
          width: recommended ? 2 : 1,
        ),
        boxShadow: recommended
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges row
          if (recommended || isCurrent)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  if (recommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        lang.isRTL ? 'الأكثر شعبية' : 'Most Popular',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (recommended && isCurrent) const SizedBox(width: 8),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        lang.isRTL ? 'خطتك الحالية' : 'Current Plan',
                        style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

          // Plan name
          Text(
            name,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceEgp == 0
                    ? (lang.isRTL ? 'مجاناً' : 'Free')
                    : priceEgp.toString(),
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: priceEgp == 0 ? 24 : 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (priceEgp > 0) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'EGP${lang.t('subscription.month')}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Features
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrent
                  ? null
                  : planKey == 'free'
                      ? () => ctx.pop()
                      : () => ctx.push('/subscription-payment', extra: {
                            'planKey': planKey,
                            'planName': name,
                            'priceEgp': priceEgp,
                          }),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isCurrent ? AppColors.border : AppColors.primary,
                foregroundColor: isCurrent ? AppColors.textSecondary : Colors.white,
                disabledBackgroundColor: AppColors.border,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isCurrent
                    ? (lang.isRTL ? 'خطتك الحالية' : 'Current Plan')
                    : planKey == 'free'
                        ? (lang.isRTL ? 'الاستمرار مجاناً' : 'Continue Free')
                        : (lang.isRTL ? 'اشترك الآن' : 'Subscribe Now'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
