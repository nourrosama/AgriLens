import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

/// Bottom navigation bar — Home, Fields, Reports, Profile
class BottomNav extends StatelessWidget {
  final String active;

  const BottomNav({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final items = [
      _NavItem('home', Icons.home_rounded, lang.t('nav.home')),
      _NavItem('fields', Icons.eco_rounded, lang.t('nav.fields')),
      _NavItem('reports', Icons.bar_chart_rounded, lang.t('nav.reports')),
      _NavItem('profile', Icons.person_rounded, lang.t('nav.profile')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.map((item) {
              final isActive = item.id == active;
              return GestureDetector(
                onTap: () {
                  // TODO: navigate to respective screens
                },
                child: SizedBox(
                  width: 70,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 28,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String id;
  final IconData icon;
  final String label;

  _NavItem(this.id, this.icon, this.label);
}
