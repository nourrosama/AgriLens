import 'package:flutter/material.dart';

/// Bilingual support — 270+ keys from Figma LanguageContext
/// Supports English (LTR) and Arabic (RTL)
class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isRTL => _locale.languageCode == 'ar';
  String get languageCode => _locale.languageCode;

  void setLanguage(String code) {
    _locale = Locale(code);
    notifyListeners();
  }

  String t(String key) {
    final map = _locale.languageCode == 'ar' ? _ar : _en;
    return map[key] ?? key;
  }

  // ─── English ────────────────────────────────────
  static const _en = {
    // Common
    'common.cancel': 'Cancel',
    'common.save': 'Save',
    'common.delete': 'Delete',
    'common.edit': 'Edit',
    'common.back': 'Back',
    'common.next': 'Next',
    'common.done': 'Done',
    'common.loading': 'Loading...',
    'common.or': 'or',

    // Units
    'units.feddan': 'Feddan',
    'units.celsius': '°C',
    'units.percent': '%',
    'units.kmh': 'km/h',

    // App
    'app.name': 'AgriLens',
    'app.tagline': 'Smart Farming Assistant',

    // Onboarding
    'onboarding.title1': 'Detect Plant Diseases',
    'onboarding.desc1':
        'Take a photo of your plant and get instant disease detection using AI technology',
    'onboarding.title2': 'Track Your Fields',
    'onboarding.desc2':
        'Monitor all your fields health and get alerts when attention is needed',
    'onboarding.title3': 'Get Expert Advice',
    'onboarding.desc3':
        'Chat with AgriBot anytime for farming tips and disease treatment guidance',
    'onboarding.skip': 'Skip',
    'onboarding.getStarted': 'Get Started',

    // Language
    'language.title': 'Choose Your Language',
    'language.subtitle': 'Select your preferred language',
    'language.english': 'English',
    'language.arabic': 'العربية',
    'language.continue': 'Continue',

    // Login
    'login.title': 'Welcome Back!',
    'login.subtitle': 'Enter your phone number to continue',
    'login.phone': 'Phone Number',
    'login.phonePlaceholder': '01234567890',
    'login.sendOTP': 'Send Code',
    'login.otpTitle': 'Enter Verification Code',
    'login.otpSubtitle': 'We sent a code to',
    'login.verify': 'Verify',
    'login.resend': 'Resend Code',
    'login.successTitle': 'Welcome!',
    'login.successMessage': 'You are now logged in',

    // Home
    'home.goodMorning': 'Good morning',
    'home.farmer': 'Farmer',
    'home.plantHealth': "Today's Plant Health",
    'home.healthyStatus': 'Healthy status across all fields',
    'home.quickScan': 'Quick Scan',
    'home.quickScanDesc': 'Detect diseases instantly',
    'home.activeAlerts': 'Active Alerts',
    'home.viewAll': 'View All',
    'home.moderateRisk': 'Moderate risk detected',
    'home.treatmentComplete': 'Treatment completed',
    'home.weatherToday': 'Weather Today',
    'home.partlyCloudy': 'Partly Cloudy',
    'home.humidity': 'Humidity',
    'home.wind': 'Wind',
    'home.myFields': 'My Fields',
    'home.forecasting': 'Forecasting',

    // Scan
    'scan.instruction': 'Point camera at affected leaf or plant',
    'scan.tip1': 'Use good lighting',
    'scan.analyzing': 'Analyzing plant...',
    'scan.resultTitle': 'Detection Result',
    'scan.confidence': 'Confidence',
    'scan.severity': 'Severity',
    'scan.viewDetails': 'View Full Details',
    'scan.scanAnother': 'Scan Another Plant',

    // Disease
    'disease.overview': 'Overview',
    'disease.symptoms': 'Symptoms',
    'disease.treatment': 'Treatment',
    'disease.prevention': 'Prevention',
    'disease.recommendedAction': 'Recommended Action',
    'disease.medium': 'Medium',

    // Nav
    'nav.home': 'Home',
    'nav.fields': 'Fields',
    'nav.reports': 'Reports',
    'nav.profile': 'Profile',
  };

  // ─── Arabic ─────────────────────────────────────
  static const _ar = {
    // Common
    'common.cancel': 'إلغاء',
    'common.save': 'حفظ',
    'common.delete': 'حذف',
    'common.edit': 'تعديل',
    'common.back': 'رجوع',
    'common.next': 'التالي',
    'common.done': 'تم',
    'common.loading': 'جاري التحميل...',
    'common.or': 'أو',

    // Units
    'units.feddan': 'فدان',
    'units.celsius': '°س',
    'units.percent': '٪',
    'units.kmh': 'كم/س',

    // App
    'app.name': 'أجري لينس',
    'app.tagline': 'مساعدك الزراعي الذكي',

    // Onboarding
    'onboarding.title1': 'اكتشف أمراض النباتات',
    'onboarding.desc1':
        'التقط صورة لنباتك واحصل على كشف فوري للأمراض باستخدام الذكاء الاصطناعي',
    'onboarding.title2': 'راقب حقولك',
    'onboarding.desc2':
        'راقب صحة جميع حقولك واحصل على تنبيهات عند الحاجة للانتباه',
    'onboarding.title3': 'احصل على نصائح الخبراء',
    'onboarding.desc3':
        'تحدث مع أجري بوت في أي وقت للحصول على نصائح زراعية وإرشادات علاج الأمراض',
    'onboarding.skip': 'تخطي',
    'onboarding.getStarted': 'ابدأ الآن',

    // Language
    'language.title': 'اختر لغتك',
    'language.subtitle': 'اختر اللغة المفضلة',
    'language.english': 'English',
    'language.arabic': 'العربية',
    'language.continue': 'متابعة',

    // Login
    'login.title': 'مرحباً بعودتك!',
    'login.subtitle': 'أدخل رقم هاتفك للمتابعة',
    'login.phone': 'رقم الهاتف',
    'login.phonePlaceholder': '01234567890',
    'login.sendOTP': 'إرسال الكود',
    'login.otpTitle': 'أدخل كود التحقق',
    'login.otpSubtitle': 'أرسلنا كوداً إلى',
    'login.verify': 'تحقق',
    'login.resend': 'إعادة إرسال الكود',
    'login.successTitle': 'أهلاً بك!',
    'login.successMessage': 'تم تسجيل الدخول بنجاح',

    // Home
    'home.goodMorning': 'صباح الخير',
    'home.farmer': 'المزارع',
    'home.plantHealth': 'صحة النباتات اليوم',
    'home.healthyStatus': 'حالة صحية جيدة في جميع الحقول',
    'home.quickScan': 'فحص سريع',
    'home.quickScanDesc': 'اكتشف الأمراض فوراً',
    'home.activeAlerts': 'التنبيهات النشطة',
    'home.viewAll': 'عرض الكل',
    'home.moderateRisk': 'تم اكتشاف خطر متوسط',
    'home.treatmentComplete': 'اكتمل العلاج',
    'home.weatherToday': 'الطقس اليوم',
    'home.partlyCloudy': 'غائم جزئياً',
    'home.humidity': 'الرطوبة',
    'home.wind': 'الرياح',
    'home.myFields': 'حقولي',
    'home.forecasting': 'التوقعات',

    // Scan
    'scan.instruction': 'وجه الكاميرا نحو الورقة أو النبات المصاب',
    'scan.tip1': 'استخدم إضاءة جيدة',
    'scan.analyzing': 'جاري تحليل النبات...',
    'scan.resultTitle': 'نتيجة الفحص',
    'scan.confidence': 'دقة التشخيص',
    'scan.severity': 'الخطورة',
    'scan.viewDetails': 'عرض التفاصيل الكاملة',
    'scan.scanAnother': 'فحص نبات آخر',

    // Disease
    'disease.overview': 'نظرة عامة',
    'disease.symptoms': 'الأعراض',
    'disease.treatment': 'العلاج',
    'disease.prevention': 'الوقاية',
    'disease.recommendedAction': 'الإجراء الموصى به',
    'disease.medium': 'متوسط',

    // Nav
    'nav.home': 'الرئيسية',
    'nav.fields': 'الحقول',
    'nav.reports': 'التقارير',
    'nav.profile': 'الملف',
  };
}
