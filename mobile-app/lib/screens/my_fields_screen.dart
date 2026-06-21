import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/bottom_nav.dart';
import 'package:agrilens/widgets/chatbot_button.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class MyFieldsScreen extends StatelessWidget {
  const MyFieldsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();
    final fieldsProvider = context.watch<FieldsProvider>();
    final fields = fieldsProvider.fields;

    // Plan gate — My Fields requires Professional
    if (user.plan != 'professional') {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          title: Text(
            lang.t('home.myFields'),
            style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
          ),
        ),
        bottomNavigationBar: const BottomNav(active: 'fields'),
        body: PlanGateBody(requiredPlan: 'professional', isRTL: lang.isRTL),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/home'),
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
                      Expanded(
                        child: Text(
                          lang.t('fields.title'),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/disease-map'),
                        child: Text(
                          lang.t('fields.viewMap'),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fieldsProvider.loadFields,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/add-field'),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    lang.t('fields.addNew'),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _quickStats(lang, fieldsProvider),
                          const SizedBox(height: 16),
                          if (fieldsProvider.isLoading && fields.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          else if (fieldsProvider.errorMessage != null &&
                              fields.isEmpty)
                            _stateCard(
                              icon: Icons.error_outline,
                              title: lang.isRTL
                                  ? 'تعذر تحميل الحقول'
                                  : 'Unable to load fields',
                              message: fieldsProvider.errorMessage!,
                              actionLabel: lang.t('common.done'),
                              onTap: fieldsProvider.loadFields,
                            )
                          else if (fields.isEmpty)
                            _stateCard(
                              icon: Icons.agriculture_outlined,
                              title: lang.isRTL
                                  ? 'لا توجد حقول بعد'
                                  : 'No fields yet',
                              message: lang.isRTL
                                  ? 'أضف أول حقل لبدء متابعة صحة المحاصيل والتنبيهات.'
                                  : 'Add your first field to start monitoring crop health and alerts.',
                              actionLabel: lang.t('fields.addNew'),
                              onTap: () => context.push('/add-field'),
                            )
                          else
                            ...fields.map(
                              (field) => _fieldCard(context, lang, field),
                            ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const ChatbotButton(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(active: 'fields'),
    );
  }

  Widget _fieldCard(
    BuildContext context,
    LanguageProvider lang,
    FieldData field,
  ) {
    final statusColor = field.status == 'healthy'
        ? AppColors.primary
        : const Color(0xFFFFC107);

    return GestureDetector(
      onTap: () => context.push('/field-overview/${field.id}'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (field.photoUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  field.photoUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.name,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              field.location.isEmpty
                                  ? (lang.isRTL
                                        ? 'لم تتم إضافة موقع'
                                        : 'No location added')
                                  : field.location,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((field.cropType ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${lang.t('fields.cropType')}: ${_localizedCrop(lang, field.cropType)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    field.status == 'healthy'
                        ? lang.t('fields.healthy')
                        : lang.t('fields.warning'),
                    style: TextStyle(color: statusColor, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _metaItem(
                    lang.t('fields.area'),
                    '${field.area} ${lang.t('units.feddan')}',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _metaItem(
                    lang.t('fields.healthScore'),
                    '${field.health}${lang.t('units.percent')}',
                  ),
                ),
              ],
            ),
            if ((field.soilType ?? '').isNotEmpty ||
                (field.irrigationType ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if ((field.soilType ?? '').isNotEmpty)
                    _tag(
                      '${lang.t('fields.soilType')}: ${_localizedSoil(lang, field.soilType)}',
                    ),
                  if ((field.irrigationType ?? '').isNotEmpty)
                    _tag(
                      '${lang.t('fields.irrigationType')}: ${_localizedIrrigation(lang, field.irrigationType)}',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (field.health / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStats(LanguageProvider lang, FieldsProvider provider) {
    return Container(
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
            lang.t('fields.overview'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth >= 540
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _statBox(
                  lang.t('fields.totalFields'),
                  '${provider.fields.length}',
                ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statBox(
                  lang.t('fields.totalArea'),
                  '${lang.localizeNum(provider.totalArea, decimals: 1)} ${lang.t('units.feddan')}',
                ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _statBox(
                  lang.t('fields.avgHealth'),
                  '${lang.localizeDigits(provider.averageHealth.toString())}${lang.t('units.percent')}',
                ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onTap, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _metaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: AppColors.primaryDark, fontSize: 18),
        ),
      ],
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primaryDark, fontSize: 12),
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: const TextStyle(color: AppColors.primaryDark, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _localizedCrop(LanguageProvider lang, String? value) {
    final key = _normalizedKey(value);
    if (key.isEmpty) return '';
    return lang.t('crops.$key');
  }

  String _localizedSoil(LanguageProvider lang, String? value) {
    final key = _normalizedKey(value);
    if (key.isEmpty) return '';
    return lang.t('soil.$key');
  }

  String _localizedIrrigation(LanguageProvider lang, String? value) {
    final key = _normalizedKey(value);
    if (key.isEmpty) return '';
    return lang.t('irrigation.$key');
  }

  String _normalizedKey(String? value) {
    return (value ?? '').trim().toLowerCase().replaceAll(' ', '');
  }
}
