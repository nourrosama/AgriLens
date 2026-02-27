import 'package:go_router/go_router.dart';
import 'package:agrilens/screens/splash_screen.dart';
import 'package:agrilens/screens/onboarding_screen.dart';
import 'package:agrilens/screens/language_selection_screen.dart';
import 'package:agrilens/screens/login_phone_screen.dart';
import 'package:agrilens/screens/login_otp_screen.dart';
import 'package:agrilens/screens/login_success_screen.dart';
import 'package:agrilens/screens/home_screen.dart';
import 'package:agrilens/screens/camera_scan_screen.dart';
import 'package:agrilens/screens/scan_result_screen.dart';
import 'package:agrilens/screens/disease_details_screen.dart';
import 'package:agrilens/screens/my_fields_screen.dart';
import 'package:agrilens/screens/add_field_screen.dart';
import 'package:agrilens/screens/edit_field_screen.dart';
import 'package:agrilens/screens/field_overview_screen.dart';
import 'package:agrilens/screens/disease_map_screen.dart';
import 'package:agrilens/screens/forecasting_screen.dart';
import 'package:agrilens/screens/reports_screen.dart';
import 'package:agrilens/screens/notifications_screen.dart';
import 'package:agrilens/screens/profile_screen.dart';
import 'package:agrilens/screens/settings_screen.dart';
import 'package:agrilens/screens/chatbot_screen.dart';
import 'package:agrilens/screens/subscription_overview_screen.dart';
import 'package:agrilens/screens/subscription_plans_screen.dart';
import 'package:agrilens/screens/subscription_payment_screen.dart';
import 'package:agrilens/screens/subscription_confirmation_screen.dart';
import 'package:agrilens/screens/active_subscription_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Auth flow
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/language', builder: (context, state) => const LanguageSelectionScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPhoneScreen()),
    GoRoute(path: '/login-otp', builder: (context, state) => const LoginOtpScreen()),
    GoRoute(path: '/login-success', builder: (context, state) => const LoginSuccessScreen()),

    // Main app
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/scan', builder: (context, state) => const CameraScanScreen()),
    GoRoute(path: '/scan-result', builder: (context, state) => const ScanResultScreen()),
    GoRoute(path: '/disease-details', builder: (context, state) => const DiseaseDetailsScreen()),

    // Fields
    GoRoute(path: '/fields', builder: (context, state) => const MyFieldsScreen()),
    GoRoute(path: '/add-field', builder: (context, state) => const AddFieldScreen()),
    GoRoute(path: '/edit-field/:id', builder: (context, state) => EditFieldScreen(fieldId: state.pathParameters['id'] ?? '1')),
    GoRoute(path: '/field-overview/:id', builder: (context, state) => FieldOverviewScreen(fieldId: state.pathParameters['id'] ?? '1')),
    GoRoute(path: '/disease-map', builder: (context, state) => const DiseaseMapScreen()),

    // Analytics
    GoRoute(path: '/forecasting', builder: (context, state) => const ForecastingScreen()),
    GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),

    // User
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(path: '/chatbot', builder: (context, state) => const ChatbotScreen()),

    // Subscription
    GoRoute(path: '/subscription', builder: (context, state) => const SubscriptionOverviewScreen()),
    GoRoute(path: '/subscription-plans', builder: (context, state) => const SubscriptionPlansScreen()),
    GoRoute(path: '/subscription-payment', builder: (context, state) => const SubscriptionPaymentScreen()),
    GoRoute(path: '/subscription-confirmation', builder: (context, state) => const SubscriptionConfirmationScreen()),
    GoRoute(path: '/active-subscription', builder: (context, state) => const ActiveSubscriptionScreen()),
  ],
);
