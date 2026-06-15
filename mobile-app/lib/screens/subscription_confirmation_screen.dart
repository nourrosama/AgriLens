import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';

class SubscriptionConfirmationScreen extends StatefulWidget {
  const SubscriptionConfirmationScreen({
    super.key,
    required this.planKey,
    required this.planName,
    required this.priceEgp,
  });

  final String planKey;
  final String planName;
  final int priceEgp;

  @override
  State<SubscriptionConfirmationScreen> createState() =>
      _SubscriptionConfirmationScreenState();
}

class _SubscriptionConfirmationScreenState
    extends State<SubscriptionConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    // Activate subscription on backend / local state
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<UserProvider>().subscribe(widget.planKey);
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _renewalDate() {
    final d = DateTime.now().add(const Duration(days: 30));
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                const SizedBox(height: 32),

                // Animated checkmark
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  lang.t('subscription.confirmTitle'),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  lang.t('subscription.confirmMessage'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Receipt card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _receiptRow(
                        lang.isRTL ? 'الخطة' : 'Plan',
                        widget.planName,
                        bold: true,
                      ),
                      const Divider(height: 20),
                      _receiptRow(
                        lang.isRTL ? 'المبلغ المدفوع' : 'Amount Paid',
                        '${widget.priceEgp} EGP',
                        valueColor: AppColors.primary,
                        bold: true,
                      ),
                      const Divider(height: 20),
                      _receiptRow(
                        lang.t('subscription.renewDate'),
                        _renewalDate(),
                      ),
                      const Divider(height: 20),
                      _receiptRow(
                        lang.isRTL ? 'الحالة' : 'Status',
                        lang.isRTL ? 'نشط ✓' : 'Active ✓',
                        valueColor: AppColors.primary,
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Receipt note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sms_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang.t('subscription.receiptSent'),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Go home button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      lang.isRTL
                          ? 'العودة إلى الرئيسية'
                          : 'Back to Home',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Manage subscription link
                TextButton(
                  onPressed: () => context.go('/subscription-plans'),
                  child: Text(
                    lang.t('subscription.manage'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.primaryDark,
            fontSize: 15,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
