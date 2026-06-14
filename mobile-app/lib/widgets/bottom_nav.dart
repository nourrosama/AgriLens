import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/language_provider.dart';

class BottomNav extends StatelessWidget {
  final String active;
  const BottomNav({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
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
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: lang.t('nav.home'),
            isActive: active == 'home',
            onTap: () => context.go('/home'),
          ),
          _NavItem(
            icon: Icons.eco_rounded,
            label: lang.t('nav.fields'),
            isActive: active == 'fields',
            onTap: () => context.go('/fields'),
          ),
          _NavItem(
            icon: Icons.forum_rounded,
            label: lang.t('nav.forum'),
            isActive: active == 'forum',
            onTap: () => context.go('/feed'),
          ),
          _NavItem(
            icon: Icons.bar_chart_rounded,
            label: lang.t('nav.reports'),
            isActive: active == 'reports',
            onTap: () => context.go('/reports'),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: lang.t('nav.profile'),
            isActive: active == 'profile',
            onTap: () => context.go('/profile'),
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
