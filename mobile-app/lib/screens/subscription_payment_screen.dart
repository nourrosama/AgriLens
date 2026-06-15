import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

enum _PayMethod { card, vodafoneCash, fawry, instaPay }

class SubscriptionPaymentScreen extends StatefulWidget {
  const SubscriptionPaymentScreen({
    super.key,
    required this.planKey,
    required this.planName,
    required this.priceEgp,
  });

  final String planKey;
  final String planName;
  final int priceEgp;

  @override
  State<SubscriptionPaymentScreen> createState() =>
      _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState
    extends State<SubscriptionPaymentScreen> {
  _PayMethod _method = _PayMethod.card;
  bool _processing = false;

  // Card fields
  final _cardNumberCtrl = TextEditingController();
  final _holderNameCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();

  // Vodafone Cash / InstaPay
  final _mobileCtrl = TextEditingController();

  // InstaPay bank
  String? _selectedBank;
  final _accountCtrl = TextEditingController();

  // Generated Fawry reference
  late final String _fawryRef;

  @override
  void initState() {
    super.initState();
    // Generate a fake Fawry reference for demo
    final ts = DateTime.now().millisecondsSinceEpoch % 1000000000;
    _fawryRef = ts.toString().padLeft(9, '0');
  }

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _holderNameCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _mobileCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _processing = true);
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _processing = false);
    context.push('/subscription-confirmation', extra: {
      'planKey': widget.planKey,
      'planName': widget.planName,
      'priceEgp': widget.priceEgp,
      'method': _method.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _processing ? null : () => context.pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Transform.flip(
                        flipX: lang.isRTL,
                        child: const Icon(Icons.arrow_back,
                            size: 28, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    lang.t('subscription.payment'),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order summary card
                    _OrderSummary(
                        planName: widget.planName,
                        priceEgp: widget.priceEgp,
                        lang: lang),
                    const SizedBox(height: 24),

                    // Payment method selector
                    Text(
                      lang.t('subscription.selectPayment'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _MethodSelector(
                      selected: _method,
                      lang: lang,
                      onChanged: (m) => setState(() => _method = m),
                    ),
                    const SizedBox(height: 24),

                    // Dynamic form
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: KeyedSubtree(
                        key: ValueKey(_method),
                        child: _buildForm(lang),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Pay button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _processing ? null : _pay,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _processing
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    lang.t('subscription.processing'),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              )
                            : Text(
                                _method == _PayMethod.fawry
                                    ? (lang.isRTL
                                        ? 'تأكيد الطلب'
                                        : 'Confirm Order')
                                    : '${lang.isRTL ? "ادفع" : "Pay"} ${widget.priceEgp} EGP',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Security note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          lang.isRTL
                              ? 'مدفوعاتك محمية بتشفير SSL'
                              : 'Your payment is secured with SSL encryption',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
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

  Widget _buildForm(LanguageProvider lang) {
    switch (_method) {
      case _PayMethod.card:
        return _CardForm(
          holderCtrl: _holderNameCtrl,
          numberCtrl: _cardNumberCtrl,
          expiryCtrl: _expiryCtrl,
          cvvCtrl: _cvvCtrl,
          lang: lang,
        );
      case _PayMethod.vodafoneCash:
        return _VodafoneForm(ctrl: _mobileCtrl, lang: lang);
      case _PayMethod.fawry:
        return _FawryForm(ref: _fawryRef, priceEgp: widget.priceEgp, lang: lang);
      case _PayMethod.instaPay:
        return _InstaPayForm(
          mobileCtrl: _mobileCtrl,
          accountCtrl: _accountCtrl,
          selectedBank: _selectedBank,
          onBankChanged: (b) => setState(() => _selectedBank = b),
          lang: lang,
        );
    }
  }
}

// ─── Order Summary ───────────────────────────────────────────────────────────

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.planName,
    required this.priceEgp,
    required this.lang,
  });
  final String planName;
  final int priceEgp;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('subscription.orderSummary'),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            planName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                lang.t('subscription.total'),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
              ),
              Text(
                '$priceEgp EGP${lang.t('subscription.month')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Method Selector ─────────────────────────────────────────────────────────

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({
    required this.selected,
    required this.lang,
    required this.onChanged,
  });
  final _PayMethod selected;
  final LanguageProvider lang;
  final ValueChanged<_PayMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final methods = [
      (_PayMethod.card, Icons.credit_card_rounded,
          lang.t('subscription.card')),
      (_PayMethod.vodafoneCash, Icons.phone_android_rounded,
          lang.t('subscription.vodafoneCash')),
      (_PayMethod.fawry, Icons.store_rounded, lang.t('subscription.fawry')),
      (_PayMethod.instaPay, Icons.flash_on_rounded,
          lang.t('subscription.instaPay')),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.8,
      children: methods.map((m) {
        final isSelected = selected == m.$1;
        return GestureDetector(
          onTap: () => onChanged(m.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isSelected ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(m.$2,
                    size: 20,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.$3,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Card Form ───────────────────────────────────────────────────────────────

class _CardForm extends StatelessWidget {
  const _CardForm({
    required this.holderCtrl,
    required this.numberCtrl,
    required this.expiryCtrl,
    required this.cvvCtrl,
    required this.lang,
  });
  final TextEditingController holderCtrl;
  final TextEditingController numberCtrl;
  final TextEditingController expiryCtrl;
  final TextEditingController cvvCtrl;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Accepted cards logos
        Row(
          children: [
            _cardBadge('VISA', const Color(0xFF1A1F71)),
            const SizedBox(width: 8),
            _cardBadge('MC', const Color(0xFFEB001B)),
            const SizedBox(width: 8),
            _cardBadge('Meeza', AppColors.primary),
          ],
        ),
        const SizedBox(height: 16),
        _field(lang.t('subscription.holderName'), 'Ahmed Mohamed', holderCtrl,
            TextInputType.name),
        const SizedBox(height: 14),
        _field(
          lang.t('subscription.cardNumber'),
          '0000  0000  0000  0000',
          numberCtrl,
          TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _CardNumberFormatter(),
          ],
          maxLength: 19,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _field(
                lang.t('subscription.expiry'),
                'MM/YY',
                expiryCtrl,
                TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ExpiryFormatter(),
                ],
                maxLength: 5,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _field(
                lang.t('subscription.cvv'),
                '•••',
                cvvCtrl,
                TextInputType.number,
                obscure: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Vodafone Cash Form ───────────────────────────────────────────────────────

class _VodafoneForm extends StatelessWidget {
  const _VodafoneForm({required this.ctrl, required this.lang});
  final TextEditingController ctrl;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCCCC)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE60000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_android,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lang.isRTL
                      ? 'ادخل رقم هاتفك المسجل في فودافون كاش وسيتم خصم المبلغ منه.'
                      : 'Enter your Vodafone Cash registered mobile number. The amount will be deducted from your wallet.',
                  style: const TextStyle(
                      color: Color(0xFF8B0000), fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _field(
          lang.t('subscription.mobileNumber'),
          '01X XXXX XXXX',
          ctrl,
          TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          prefix: const Text('+20  ',
              style: TextStyle(
                  color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            lang.isRTL
                ? '• ستتلقى رسالة SMS لتأكيد الدفع\n• يمكنك أيضاً الدفع عبر تطبيق فودافون كاش'
                : '• You will receive an SMS to confirm payment\n• You can also pay via the Vodafone Cash app',
            style: const TextStyle(
                color: Color(0xFFCC6600), fontSize: 12, height: 1.6),
          ),
        ),
      ],
    );
  }
}

// ─── Fawry Form ──────────────────────────────────────────────────────────────

class _FawryForm extends StatelessWidget {
  const _FawryForm({
    required this.ref,
    required this.priceEgp,
    required this.lang,
  });
  final String ref;
  final int priceEgp;
  final LanguageProvider lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                lang.t('subscription.fawryCode'),
                style: const TextStyle(
                    color: Color(0xFF5D4037),
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              // Reference code with copy button
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF6D00)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ref,
                      style: const TextStyle(
                        color: Color(0xFFFF6D00),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: ref));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(lang.isRTL
                              ? 'تم نسخ الكود'
                              : 'Code copied!'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.primary,
                        ));
                      },
                      child: const Icon(Icons.copy_rounded,
                          color: Color(0xFFFF6D00), size: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$priceEgp EGP',
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.isRTL
                    ? 'كيفية الدفع بفوري:'
                    : 'How to pay with Fawry:',
                style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              const SizedBox(height: 10),
              ...([
                lang.isRTL
                    ? 'اذهب إلى أقرب منفذ فوري أو افتح تطبيق فوري'
                    : 'Go to any Fawry outlet or open the Fawry app',
                lang.isRTL
                    ? 'اختر "دفع الفواتير" ثم "AgriLens"'
                    : 'Choose "Bill Payment" then "AgriLens"',
                lang.isRTL
                    ? 'ادخل كود الرجوع أعلاه'
                    : 'Enter the reference code above',
                lang.isRTL
                    ? 'ادفع المبلغ وستُفعَّل خطتك تلقائياً'
                    : 'Pay the amount and your plan will activate automatically',
              ].asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6D00),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${e.key + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(e.value,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── InstaPay Form ────────────────────────────────────────────────────────────

class _InstaPayForm extends StatelessWidget {
  const _InstaPayForm({
    required this.mobileCtrl,
    required this.accountCtrl,
    required this.selectedBank,
    required this.onBankChanged,
    required this.lang,
  });
  final TextEditingController mobileCtrl;
  final TextEditingController accountCtrl;
  final String? selectedBank;
  final ValueChanged<String?> onBankChanged;
  final LanguageProvider lang;

  static const _banks = [
    'CIB',
    'NBE — National Bank of Egypt',
    'Banque Misr',
    'QNB Alahli',
    'HSBC Egypt',
    'Banque du Caire',
    'Alex Bank',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: Row(
            children: [
              const Icon(Icons.flash_on_rounded,
                  color: Color(0xFF1565C0), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.isRTL
                      ? 'حوّل المبلغ فوراً عبر تطبيق البنك الخاص بك باستخدام رقم هاتفك.'
                      : 'Transfer instantly via your bank app using your mobile number.',
                  style: const TextStyle(
                      color: Color(0xFF1565C0), fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _field(
          lang.t('subscription.mobileNumber'),
          '01X XXXX XXXX',
          mobileCtrl,
          TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          prefix: const Text('+20  ',
              style: TextStyle(
                  color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 14),
        // Bank dropdown
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.t('subscription.bankName'),
              style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedBank,
              hint: Text(lang.isRTL ? 'اختر بنكك' : 'Select your bank',
                  style:
                      const TextStyle(color: AppColors.textSecondary)),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              items: _banks
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: onBankChanged,
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared field widget ──────────────────────────────────────────────────────

Widget _field(
  String label,
  String hint,
  TextEditingController ctrl,
  TextInputType type, {
  bool obscure = false,
  List<TextInputFormatter>? inputFormatters,
  int? maxLength,
  Widget? prefix,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          prefixText: prefix == null ? null : '',
          prefix: prefix,
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.border, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.border, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    ],
  );
}

// ─── Input Formatters ─────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('  ');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final str = buffer.toString();
    return next.copyWith(
      text: str,
      selection: TextSelection.collapsed(offset: str.length),
    );
  }
}
