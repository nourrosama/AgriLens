import 'package:go_router/go_router.dart';
import 'package:agrilens/screens/splash_screen.dart';
import 'package:agrilens/screens/onboarding_screen.dart';
import 'package:agrilens/screens/language_selection_screen.dart';
import 'package:agrilens/screens/login_phone_screen.dart';
import 'package:agrilens/screens/login_otp_screen.dart';
import 'package:agrilens/screens/login_success_screen.dart';
import 'package:agrilens/screens/user_registration_screen.dart';
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
import 'package:agrilens/screens/edit_profile_screen.dart';
import 'package:agrilens/screens/settings_screen.dart';
import 'package:agrilens/screens/chatbot_screen.dart';
import 'package:agrilens/screens/subscription_overview_screen.dart';
import 'package:agrilens/screens/subscription_plans_screen.dart';
import 'package:agrilens/screens/subscription_payment_screen.dart';
import 'package:agrilens/screens/subscription_confirmation_screen.dart';
import 'package:agrilens/screens/active_subscription_screen.dart';
import 'package:agrilens/screens/faq_screen.dart';
import 'package:agrilens/screens/terms_conditions_screen.dart';
import 'package:agrilens/screens/data_privacy_screen.dart';
import 'package:agrilens/screens/contact_support_screen.dart';
import 'package:agrilens/screens/app_tutorial_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Auth & onboarding flow
    GoRoute(path: '/', builder: (ctx, s) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (ctx, s) => const OnboardingScreen()),
    GoRoute(path: '/language', builder: (ctx, s) => const LanguageSelectionScreen()),
    // Registration — matches TSX route /registration
    GoRoute(path: '/registration', builder: (ctx, s) => const UserRegistrationScreen()),
    GoRoute(path: '/register', redirect: (ctx, s) => '/registration'),
    GoRoute(path: '/login', builder: (ctx, s) => const LoginPhoneScreen()),
    GoRoute(path: '/login-otp', builder: (ctx, s) => const LoginOtpScreen()),
    GoRoute(path: '/login-success', builder: (ctx, s) => const LoginSuccessScreen()),

    // Main app
    GoRoute(path: '/home', builder: (ctx, s) => const HomeScreen()),
    GoRoute(path: '/scan', builder: (ctx, s) => const CameraScanScreen()),
    GoRoute(path: '/scan-result', builder: (ctx, s) => const ScanResultScreen()),
    GoRoute(path: '/disease-details', builder: (ctx, s) => const DiseaseDetailsScreen()),

    // Fields
    GoRoute(path: '/fields', builder: (ctx, s) => const MyFieldsScreen()),
    GoRoute(path: '/add-field', builder: (ctx, s) => const AddFieldScreen()),
    GoRoute(path: '/edit-field/:id', builder: (ctx, s) =>
        EditFieldScreen(fieldId: s.pathParameters['id'] ?? '1')),
    GoRoute(path: '/field-overview/:id', builder: (ctx, s) =>
        FieldOverviewScreen(fieldId: s.pathParameters['id'] ?? '1')),
    GoRoute(path: '/disease-map', builder: (ctx, s) => const DiseaseMapScreen()),

    // Analytics
    GoRoute(path: '/forecasting', builder: (ctx, s) => const ForecastingScreen()),
    GoRoute(path: '/reports', builder: (ctx, s) => const ReportsScreen()),

    // User
    GoRoute(path: '/notifications', builder: (ctx, s) => const NotificationsScreen()),
    GoRoute(path: '/profile', builder: (ctx, s) => const ProfileScreen()),
    GoRoute(path: '/edit-profile', builder: (ctx, s) => const EditProfileScreen()),
    GoRoute(path: '/settings', builder: (ctx, s) => const SettingsScreen()),
    GoRoute(path: '/chatbot', builder: (ctx, s) => const ChatbotScreen()),

    // Help & Legal
    GoRoute(path: '/faq', builder: (ctx, s) => const FaqScreen()),
    GoRoute(path: '/terms-conditions', builder: (ctx, s) => const TermsConditionsScreen()),
    GoRoute(path: '/data-privacy', builder: (ctx, s) => const DataPrivacyScreen()),
    GoRoute(path: '/contact-support', builder: (ctx, s) => const ContactSupportScreen()),
    GoRoute(path: '/app-tutorial', builder: (ctx, s) => const AppTutorialScreen()),

    // Subscription
    GoRoute(path: '/subscription', builder: (ctx, s) => const SubscriptionOverviewScreen()),
    GoRoute(path: '/subscription-plans', builder: (ctx, s) => const SubscriptionPlansScreen()),
    GoRoute(path: '/subscription-payment', builder: (ctx, s) => const SubscriptionPaymentScreen()),
    GoRoute(path: '/subscription-confirmation', builder: (ctx, s) => const SubscriptionConfirmationScreen()),
    GoRoute(path: '/active-subscription', builder: (ctx, s) => const ActiveSubscriptionScreen()),
  ],
);
