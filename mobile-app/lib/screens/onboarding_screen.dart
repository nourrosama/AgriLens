import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';

/// 3-step onboarding with PageView, dot indicators, and mascot image
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    final pages = [
      _OnboardingPage(
        titleKey: 'onboarding.title1',
        descKey: 'onboarding.desc1',
        icon: Icons.camera_alt_rounded,
      ),
      _OnboardingPage(
        titleKey: 'onboarding.title2',
        descKey: 'onboarding.desc2',
        icon: Icons.eco_rounded,
      ),
      _OnboardingPage(
        titleKey: 'onboarding.title3',
        descKey: 'onboarding.desc3',
        icon: Icons.chat_rounded,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: lang.isRTL
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/language'),
                  child: Text(
                    lang.t('onboarding.skip'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              // Page view
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _buildPage(context, pages[i], lang),
                ),
              ),

              // Dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Next / Get Started button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < pages.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      context.go('/language');
                    }
                  },
                  child: Text(
                    _currentPage == pages.length - 1
                        ? lang.t('onboarding.getStarted')
                        : lang.t('common.next'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
      BuildContext context, _OnboardingPage page, LanguageProvider lang) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mascot / illustration
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            page.icon,
            size: 80,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 40),
        Text(
          lang.t(page.titleKey),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            lang.t(page.descKey),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingPage {
  final String titleKey;
  final String descKey;
  final IconData icon;

  _OnboardingPage({
    required this.titleKey,
    required this.descKey,
    required this.icon,
  });
}
