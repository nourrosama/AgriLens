import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

// ─── Plan metadata ────────────────────────────────────────────────────────────

class _UsageItem {
  const _UsageItem({
    required this.labelKey,
    required this.usedEn,
    required this.usedAr,
    required this.totalEn,
    required this.totalAr,
    required this.progress,
  });

  final String labelKey;
  final String usedEn;
  final String usedAr;
  final String totalEn;
  final String totalAr;
  final double progress;
}

class _PlanMeta {
  const _PlanMeta({
    required this.nameEn,
    required this.nameAr,
    required this.priceEgp,
    required this.featuresEn,
    required this.featuresAr,
    required this.usageItems,
  });

  final String nameEn;
  final String nameAr;
  final int priceEgp;
  final List<String> featuresEn;
  final List<String> featuresAr;
  final List<_UsageItem> usageItems;
}

const _kUnlimitedEn = 'Unlimited';
const _kUnlimitedAr = 'غير محدود';

const _kPlans = <String, _PlanMeta>{
  'free': _PlanMeta(
    nameEn: 'Free',
    nameAr: 'مجاني',
    priceEgp: 0,
    featuresEn: [
      'Disease detection from image',
      'Confidence score',
      'Basic disease description',
      'Basic treatment recommendations',
      'Maximum 5 scans per month',
    ],
    featuresAr: [
      'كشف الأمراض من الصورة',
      'درجة الثقة',
      'وصف أساسي للمرض',
      'توصيات علاج أساسية',
      'حد أقصى 5 فحوصات شهرياً',
    ],
    usageItems: [
      _UsageItem(
        labelKey: 'nav.scan',
        usedEn: '3',
        usedAr: '3',
        totalEn: '5 / month',
        totalAr: '5 / شهر',
        progress: 0.6,
      ),
    ],
  ),
  'premium': _PlanMeta(
    nameEn: 'Premium',
    nameAr: 'بريميوم',
    priceEgp: 499,
    featuresEn: [
      'All Free features',
      'Detailed AI-generated reports',
      'Disease severity assessment',
      'Symptoms and causes analysis',
      'Recovery timeline',
      'Preventive measures',
      'Weather-based disease risk assessment',
      'Personalized recommendations',
      'Unlimited scans',
      'AI agricultural chatbot',
    ],
    featuresAr: [
      'كل ميزات النسخة المجانية',
      'تقارير تفصيلية بالذكاء الاصطناعي',
      'تقييم شدة المرض',
      'تحليل الأعراض والأسباب',
      'الجدول الزمني للتعافي',
      'تدابير وقائية',
      'تقييم مخاطر الأمراض بناءً على الطقس',
      'توصيات مخصصة',
      'فحوصات غير محدودة',
      'روبوت دردشة زراعي بالذكاء الاصطناعي',
    ],
    usageItems: [
      _UsageItem(
        labelKey: 'nav.scan',
        usedEn: '156',
        usedAr: '156',
        totalEn: _kUnlimitedEn,
        totalAr: _kUnlimitedAr,
        progress: 0.6,
      ),
      _UsageItem(
        labelKey: 'nav.reports',
        usedEn: '8',
        usedAr: '8',
        totalEn: _kUnlimitedEn,
        totalAr: _kUnlimitedAr,
        progress: 0.4,
      ),
    ],
  ),
  'professional': _PlanMeta(
    nameEn: 'Professional',
    nameAr: 'احترافي',
    priceEgp: 1499,
    featuresEn: [
      'All Premium features',
      'PDF report generation',
      'Disease history tracking',
      'Farm dashboard',
      'Disease trend analytics',
      'Yield impact estimation',
      'Treatment cost estimation',
      'Farm-wide insights',
    ],
    featuresAr: [
      'كل ميزات بريميوم',
      'إنشاء تقارير PDF',
      'تتبع تاريخ الأمراض',
      'لوحة تحكم المزرعة',
      'تحليلات اتجاهات الأمراض',
      'تقدير تأثير المحصول',
      'تقدير تكلفة العلاج',
      'رؤى على مستوى المزرعة',
    ],
    usageItems: [
      _UsageItem(
        labelKey: 'nav.scan',
        usedEn: '1 240',
        usedAr: '1 240',
        totalEn: _kUnlimitedEn,
        totalAr: _kUnlimitedAr,
        progress: 0.5,
      ),
      _UsageItem(
        labelKey: 'nav.reports',
        usedEn: '47',
        usedAr: '47',
        totalEn: _kUnlimitedEn,
        totalAr: _kUnlimitedAr,
        progress: 0.45,
      ),
      _UsageItem(
        labelKey: 'nav.fields',
        usedEn: '24',
        usedAr: '24',
        totalEn: _kUnlimitedEn,
        totalAr: _kUnlimitedAr,
        progress: 0.35,
      ),
    ],
  ),
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class ActiveSubscriptionScreen extends StatelessWidget {
  const ActiveSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();

    final meta = _kPlans[user.plan] ?? _kPlans['free']!;
    final isPaid = meta.priceEgp > 0;
    final planName = lang.isRTL ? meta.nameAr : meta.nameEn;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
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
                    lang.t('subscription.manage'),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan hero
                    _PlanHeroCard(
                      planName: planName,
                      priceEgp: meta.priceEgp,
                      lang: lang,
                      isPaid: isPaid,
                    ),
                    const SizedBox(height: 24),

                    // Renewal date (paid only)
                    if (isPaid) ...[
                      _DetailCard(
                        lang: lang,
                        items: [
                          [
                            lang.t('subscription.renewDate'),
                            lang.isRTL ? '15 مارس 2027' : 'March 15, 2027',
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Included features
                    _FeaturesCard(
                      lang: lang,
                      features: lang.isRTL ? meta.featuresAr : meta.featuresEn,
                    ),
                    const SizedBox(height: 16),

                    // Usage
                    _UsageCard(lang: lang, items: meta.usageItems),
                    const SizedBox(height: 24),

                    // Action
                    if (isPaid)
                      _CancelButton(lang: lang)
                    else
                      _UpgradeButton(lang: lang),
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

// ─── Plan hero card ───────────────────────────────────────────────────────────

class _PlanHeroCard extends StatelessWidget {
  const _PlanHeroCard({
    required this.planName,
    required this.priceEgp,
    required this.lang,
    required this.isPaid,
  });

  final String planName;
  final int priceEgp;
  final LanguageProvider lang;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final priceLabel = priceEgp == 0
        ? (lang.isRTL ? 'مجاناً' : 'Free')
        : '$priceEgp EGP${lang.t('subscription.month')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isPaid
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              )
            : LinearGradient(
                colors: [
                  AppColors.primaryLight.withValues(alpha: 0.6),
                  AppColors.primaryLight,
                ],
              ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                planName,
                style: TextStyle(
                  color: isPaid ? Colors.white : AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lang.isRTL ? 'نشط' : 'Active',
                  style: TextStyle(
                    color: isPaid ? Colors.white : AppColors.primaryDark,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            priceLabel,
            style: TextStyle(
              color: isPaid ? Colors.white : AppColors.primaryDark,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail card ──────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.lang, required this.items});
  final LanguageProvider lang;
  final List<List<String>> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items
            .where((i) => i.length >= 2 && i[1].isNotEmpty)
            .map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(i[0],
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 16)),
                    Text(i[1],
                        style: const TextStyle(
                            color: AppColors.primaryDark, fontSize: 16)),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ─── Features card ────────────────────────────────────────────────────────────

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({required this.lang, required this.features});
  final LanguageProvider lang;
  final List<String> features;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.isRTL ? 'الميزات المتاحة' : 'Included Features',
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Usage card ───────────────────────────────────────────────────────────────

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.lang, required this.items});
  final LanguageProvider lang;
  final List<_UsageItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('subscription.usage'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((e) => Column(
                children: [
                  if (e.key > 0) const SizedBox(height: 16),
                  _UsageBar(lang: lang, item: e.value),
                ],
              )),
        ],
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.lang, required this.item});
  final LanguageProvider lang;
  final _UsageItem item;

  @override
  Widget build(BuildContext context) {
    final used = lang.isRTL ? item.usedAr : item.usedEn;
    final total = lang.isRTL ? item.totalAr : item.totalEn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lang.t(item.labelKey),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            Text('$used / $total',
                style: const TextStyle(color: AppColors.primaryDark, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: item.progress,
            minHeight: 8,
            backgroundColor: AppColors.background,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ─── Action buttons ───────────────────────────────────────────────────────────

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.lang});
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF44336),
          padding: const EdgeInsets.symmetric(vertical: 20),
          side: const BorderSide(color: Color(0xFFF44336), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          lang.t('subscription.cancelPlan'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.lang});
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.push('/subscription-plans'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          lang.isRTL ? 'ترقية الخطة' : 'Upgrade Plan',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
