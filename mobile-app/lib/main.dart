import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/core/notifications_provider.dart';
import 'package:agrilens/core/chat_history_provider.dart';
import 'package:agrilens/core/community_provider.dart';
import 'package:agrilens/core/forum_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/weather_provider.dart';
import 'package:agrilens/core/crop_provider.dart';
import 'package:agrilens/core/connectivity_provider.dart';
import 'package:agrilens/core/favourites_provider.dart';
import 'package:agrilens/widgets/connectivity_banner.dart';
import 'package:agrilens/core/router.dart';
import 'package:agrilens/core/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FcmService.init();

  // Navigate to the scan result screen when a notification is tapped.
  FcmService.onNotificationTap = (scanId) {
    appRouter.push('/scan-result', extra: scanId);
  };

  runApp(const AgriLensApp());

  // If the app was cold-started by tapping a notification, the router wasn't
  // mounted yet when FcmService.init() ran. consumePendingDeepLink() defers the
  // navigation to the first rendered frame, by which time the router is ready.
  FcmService.consumePendingDeepLink();
}

class AgriLensApp extends StatelessWidget {
  const AgriLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        // UserProvider must come before any ProxyProvider that depends on it.
        ChangeNotifierProvider(create: (_) => UserProvider()),
        // These three hold user-specific data and must clear when the user
        // logs out or switches accounts. The proxy calls onUserChanged()
        // whenever UserProvider notifies; the provider itself guards against
        // no-op calls (same userId → early return).
        ChangeNotifierProxyProvider<UserProvider, FieldsProvider>(
          create: (_) => FieldsProvider(),
          update: (_, user, prev) {
            prev!.onUserChanged(user.isLoggedIn ? user.userId : '');
            return prev;
          },
        ),
        ChangeNotifierProxyProvider<UserProvider, NotificationsProvider>(
          create: (_) => NotificationsProvider(),
          update: (_, user, prev) {
            prev!.onUserChanged(user.isLoggedIn ? user.userId : '');
            return prev;
          },
        ),
        ChangeNotifierProxyProvider<UserProvider, ScanHistoryProvider>(
          create: (_) => ScanHistoryProvider(),
          update: (_, user, prev) {
            prev!.onUserChanged(user.isLoggedIn ? user.userId : '');
            return prev;
          },
        ),
        ChangeNotifierProvider(create: (_) => ChatHistoryProvider()),
        ChangeNotifierProvider(create: (_) => ForumProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => CropProvider()),
        ChangeNotifierProvider(create: (_) => FavouritesProvider()),
        // ConnectivityProvider wired to ScanHistoryProvider for auto-sync.
        ChangeNotifierProxyProvider<ScanHistoryProvider, ConnectivityProvider>(
          create: (_) => ConnectivityProvider(),
          update: (_, scanHistory, connectivity) {
            connectivity!.attachScanHistory(scanHistory);
            return connectivity;
          },
        ),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, lang, _) {
          return MaterialApp.router(
            title: 'AgriLens',
            debugShowCheckedModeBanner: false,
            locale: lang.locale,
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme.copyWith(
              textTheme: lang.isRTL
                  ? GoogleFonts.notoSansArabicTextTheme(
                      AppTheme.lightTheme.textTheme,
                    )
                  : GoogleFonts.interTextTheme(AppTheme.lightTheme.textTheme),
            ),
            routerConfig: appRouter,
            builder: (context, child) {
              // Hold rendering until the ARB file is loaded (~10ms).
              if (!lang.isReady) {
                return const ColoredBox(color: Colors.white);
              }
              return Directionality(
                textDirection:
                    lang.isRTL ? TextDirection.rtl : TextDirection.ltr,
                child: ConnectivityBanner(child: child!),
              );
            },
          );
        },
      ),
    );
  }
}