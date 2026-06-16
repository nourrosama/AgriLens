import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shows a modal bottom sheet explaining that the current plan does not
/// include the requested feature and offering an upgrade path.
///
/// [requiredPlan] must be either `'premium'` or `'professional'`.
void showPlanGateSheet(
  BuildContext context, {
  required String requiredPlan,
  required bool isRTL,
}) {
  final planName = requiredPlan == 'premium'
      ? (isRTL ? 'بريميوم' : 'Premium')
      : (isRTL ? 'الاحترافي' : 'Professional');

  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: Colors.white,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Lock icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFF9E9E9E),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            isRTL
                ? 'هذه الميزة غير متاحة في خطتك الحالية'
                : 'This feature is not available on your current plan',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Subtitle
          Text(
            isRTL
                ? 'قم بالترقية إلى خطة $planName للوصول إلى هذه الميزة.'
                : 'Upgrade to the $planName plan to unlock this feature.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Upgrade button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/subscription-plans');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                isRTL ? 'ترقية الخطة' : 'Upgrade Plan',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Dismiss link
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isRTL ? 'ربما لاحقاً' : 'Maybe Later',
              style: const TextStyle(
                color: Color(0xFF757575),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen gate body (used inside Scaffold body of locked screens)
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page lock widget shown when the user's plan doesn't include a screen.
/// Drop this as the `body` of a [Scaffold] (keep the AppBar).
///
/// [requiredPlan] must be either `'premium'` or `'professional'`.
class PlanGateBody extends StatelessWidget {
  const PlanGateBody({
    super.key,
    required this.requiredPlan,
    required this.isRTL,
  });

  final String requiredPlan;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final planName = requiredPlan == 'premium'
        ? (isRTL ? 'بريميوم' : 'Premium')
        : (isRTL ? 'الاحترافي' : 'Professional');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF9E9E9E),
                size: 44,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              isRTL
                  ? 'هذه الميزة غير متاحة في خطتك الحالية'
                  : 'Not available on your current plan',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isRTL
                  ? 'قم بالترقية إلى خطة $planName للوصول إلى هذه الميزة.'
                  : 'Upgrade to the $planName plan to unlock this feature.',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF757575),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/subscription-plans'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isRTL ? 'ترقية الخطة' : 'Upgrade Plan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(
                isRTL ? 'رجوع' : 'Go Back',
                style: const TextStyle(
                  color: Color(0xFF757575),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
