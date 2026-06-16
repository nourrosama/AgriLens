import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/widgets/plan_gate.dart';

class BottomNav extends StatelessWidget {
  final String active;
  const BottomNav({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final user = context.watch<UserProvider>();

    final isPremiumPlus = user.plan == 'premium' || user.plan == 'professional';
    final isProfessional = user.plan == 'professional';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE0E0E0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: lang.t('nav.home'),
              isActive: active == 'home',
              onTap: () => context.go('/home'),
            ),
          ),
          // Fields → Professional only
          Expanded(
            child: _NavItem(
              icon: Icons.eco_rounded,
              label: lang.t('nav.fields'),
              isActive: active == 'fields',
              locked: !isProfessional,
              onTap: () {
                if (isProfessional) {
                  context.go('/fields');
                } else {
                  showPlanGateSheet(
                    context,
                    requiredPlan: 'professional',
                    isRTL: lang.isRTL,
                  );
                }
              },
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.forum_rounded,
              label: lang.t('nav.forum'),
              isActive: active == 'forum',
              onTap: () => context.go('/feed'),
            ),
          ),
          // Reports → Professional only
          Expanded(
            child: _NavItem(
              icon: Icons.bar_chart_rounded,
              label: lang.t('nav.reports'),
              isActive: active == 'reports',
              locked: !isProfessional,
              onTap: () {
                if (isProfessional) {
                  context.go('/reports');
                } else {
                  showPlanGateSheet(
                    context,
                    requiredPlan: 'professional',
                    isRTL: lang.isRTL,
                  );
                }
              },
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              label: lang.t('nav.profile'),
              isActive: active == 'profile',
              onTap: () => context.go('/profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool locked;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? const Color(0xFF4CAF50)
        : locked
            ? const Color(0xFFBDBDBD)
            : const Color(0xFF9E9E9E);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 24, color: color),
              if (locked)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFBDBDBD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 7,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
