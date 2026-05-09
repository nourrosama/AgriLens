import 'package:go_router/go_router.dart';

import 'package:agrilens/screens/add_field_screen.dart';
import 'package:agrilens/screens/app_tutorial_screen.dart';
import 'package:agrilens/screens/camera_scan_screen.dart';
import 'package:agrilens/screens/chatbot_screen.dart';
import 'package:agrilens/screens/contact_support_screen.dart';
import 'package:agrilens/screens/data_privacy_screen.dart';
import 'package:agrilens/screens/disease_details_screen.dart';
import 'package:agrilens/screens/disease_map_screen.dart';
import 'package:agrilens/screens/edit_field_screen.dart';
import 'package:agrilens/screens/edit_profile_screen.dart';
import 'package:agrilens/screens/faq_screen.dart';
import 'package:agrilens/screens/field_overview_screen.dart';
import 'package:agrilens/screens/forecasting_screen.dart';
import 'package:agrilens/screens/home_screen.dart';
import 'package:agrilens/screens/language_selection_screen.dart';
import 'package:agrilens/screens/login_otp_screen.dart';
import 'package:agrilens/screens/login_phone_screen.dart';
import 'package:agrilens/screens/login_success_screen.dart';
import 'package:agrilens/screens/my_fields_screen.dart';
import 'package:agrilens/screens/notifications_screen.dart';
import 'package:agrilens/screens/onboarding_screen.dart';
import 'package:agrilens/screens/profile_screen.dart';
import 'package:agrilens/screens/reports_screen.dart';
import 'package:agrilens/screens/scan_result_screen.dart';
import 'package:agrilens/screens/settings_screen.dart';
import 'package:agrilens/screens/splash_screen.dart';
import 'package:agrilens/screens/ask_question_screen.dart';
import 'package:agrilens/screens/community_screen.dart';
import 'package:agrilens/screens/create_post_screen.dart';
import 'package:agrilens/screens/disease_articles_screen.dart';
import 'package:agrilens/screens/feed_screen.dart';
import 'package:agrilens/screens/question_screen.dart';
import 'package:agrilens/screens/terms_conditions_screen.dart';
import 'package:agrilens/screens/user_registration_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (ctx, state) => const SplashScreen()),
    GoRoute(
      path: '/onboarding',
      builder: (ctx, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/language',
      builder: (ctx, state) => const LanguageSelectionScreen(),
    ),
    GoRoute(
      path: '/registration',
      builder: (ctx, state) => const UserRegistrationScreen(),
    ),
    GoRoute(path: '/register', redirect: (ctx, state) => '/registration'),
    GoRoute(path: '/login', builder: (ctx, state) => const LoginPhoneScreen()),
    GoRoute(
      path: '/login-otp',
      builder: (ctx, state) => const LoginOtpScreen(),
    ),
    GoRoute(
      path: '/login-success',
      builder: (ctx, state) => const LoginSuccessScreen(),
    ),
    GoRoute(path: '/home', builder: (ctx, state) => const HomeScreen()),
    GoRoute(
      path: '/scan',
      builder: (ctx, state) => CameraScanScreen(
        farmId: state.uri.queryParameters['farmId'],
        fieldId: state.uri.queryParameters['fieldId'],
        initialCropType: state.uri.queryParameters['cropType'],
      ),
    ),
    GoRoute(
      path: '/scan-result',
      builder: (ctx, state) => const ScanResultScreen(),
    ),
    GoRoute(
      path: '/disease-details',
      builder: (ctx, state) => const DiseaseDetailsScreen(),
    ),
    GoRoute(path: '/fields', builder: (ctx, state) => const MyFieldsScreen()),
    GoRoute(
      path: '/add-field',
      builder: (ctx, state) => const AddFieldScreen(),
    ),
    GoRoute(
      path: '/edit-field/:id',
      builder: (ctx, state) =>
          EditFieldScreen(fieldId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/field-overview/:id',
      builder: (ctx, state) =>
          FieldOverviewScreen(fieldId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/disease-map',
      builder: (ctx, state) => const DiseaseMapScreen(),
    ),
    GoRoute(
      path: '/forecasting',
      builder: (ctx, state) => const ForecastingScreen(),
    ),
    GoRoute(path: '/reports', builder: (ctx, state) => const ReportsScreen()),
    GoRoute(
      path: '/notifications',
      builder: (ctx, state) => const NotificationsScreen(),
    ),
    GoRoute(path: '/profile', builder: (ctx, state) => const ProfileScreen()),
    GoRoute(
      path: '/edit-profile',
      builder: (ctx, state) => const EditProfileScreen(),
    ),
    GoRoute(path: '/settings', builder: (ctx, state) => const SettingsScreen()),
    GoRoute(path: '/chatbot', builder: (ctx, state) => const ChatbotScreen()),
    GoRoute(path: '/feed', builder: (ctx, state) => const FeedScreen()),
    GoRoute(
      path: '/create-post',
      builder: (ctx, state) => const CreatePostScreen(),
    ),
    GoRoute(
      path: '/question/:id',
      builder: (ctx, state) =>
          QuestionScreen(questionId: state.pathParameters['id'] ?? ''),
    ),
    GoRoute(
      path: '/community/:slug',
      builder: (ctx, state) =>
          CommunityScreen(cropSlug: state.pathParameters['slug'] ?? ''),
    ),
    GoRoute(
      path: '/ask-question',
      builder: (ctx, state) => const AskQuestionScreen(),
    ),
    GoRoute(
      path: '/disease-articles',
      builder: (ctx, state) => DiseaseArticlesScreen(
        disease: state.uri.queryParameters['disease'] ?? '',
        crop: state.uri.queryParameters['crop'] ?? '',
      ),
    ),
    GoRoute(path: '/faq', builder: (ctx, state) => const FaqScreen()),
    GoRoute(
      path: '/terms-conditions',
      builder: (ctx, state) => const TermsConditionsScreen(),
    ),
    GoRoute(
      path: '/data-privacy',
      builder: (ctx, state) => const DataPrivacyScreen(),
    ),
    GoRoute(
      path: '/contact-support',
      builder: (ctx, state) => const ContactSupportScreen(),
    ),
    GoRoute(
      path: '/app-tutorial',
      builder: (ctx, state) => const AppTutorialScreen(),
    ),
    GoRoute(path: '/subscription', redirect: (ctx, state) => '/profile'),
    GoRoute(path: '/subscription-plans', redirect: (ctx, state) => '/profile'),
    GoRoute(
      path: '/subscription-payment',
      redirect: (ctx, state) => '/profile',
    ),
    GoRoute(
      path: '/subscription-confirmation',
      redirect: (ctx, state) => '/profile',
    ),
    GoRoute(path: '/active-subscription', redirect: (ctx, state) => '/profile'),
  ],
);
