import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:agrilens/core/theme.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/user_provider.dart';
import 'package:agrilens/core/notifications_provider.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/weather_provider.dart';
import 'package:agrilens/core/crop_provider.dart';
import 'package:agrilens/core/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgriLensApp());
}

class AgriLensApp extends StatelessWidget {
  const AgriLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => FieldsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
        ChangeNotifierProvider(create: (_) => ScanHistoryProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => CropProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, lang, _) {
          return MaterialApp.router(
            title: 'AgriLens',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme.copyWith(
              textTheme: lang.isRTL
                  ? GoogleFonts.notoSansArabicTextTheme(
                      AppTheme.lightTheme.textTheme,
                    )
                  : GoogleFonts.interTextTheme(AppTheme.lightTheme.textTheme),
            ),
            routerConfig: appRouter,
            builder: (context, child) {
              return Directionality(
                textDirection: lang.isRTL
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
