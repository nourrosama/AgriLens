import 'package:go_router/go_router.dart';
import 'package:agrilens/screens/splash_screen.dart';
import 'package:agrilens/screens/onboarding_screen.dart';
import 'package:agrilens/screens/language_selection_screen.dart';
import 'package:agrilens/screens/login_phone_screen.dart';
import 'package:agrilens/screens/login_otp_screen.dart';
import 'package:agrilens/screens/login_success_screen.dart';
import 'package:agrilens/screens/home_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
        path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(
        path: '/language',
        builder: (context, state) => const LanguageSelectionScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPhoneScreen()),
    GoRoute(path: '/login-otp', builder: (context, state) => const LoginOtpScreen()),
    GoRoute(
        path: '/login-success',
        builder: (context, state) => const LoginSuccessScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
  ],
);
