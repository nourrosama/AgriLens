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
    'home.alerts': 'Alerts',
    'home.viewAll': 'View All',
    'home.moderateRisk': 'Moderate risk detected',
    'home.treatmentComplete': 'Treatment completed',
    'home.weatherToday': 'Weather Today',
    'home.partlyCloudy': 'Partly Cloudy',
    'home.temp': 'Temperature',
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
    'disease.low': 'Low',
    'disease.high': 'High',

    // Nav
    'nav.home': 'Home',
    'nav.scan': 'Scans',
    'nav.fields': 'Fields',
    'nav.reports': 'Reports',
    'nav.profile': 'Profile',

    // Fields
    'fields.title': 'My Fields',
    'fields.addNew': 'Add New Field',
    'fields.viewMap': 'View Map',
    'fields.healthy': 'Healthy',
    'fields.warning': 'Warning',
    'fields.area': 'Area',
    'fields.healthScore': 'Health Score',
    'fields.health': 'Health',
    'fields.riskLevel': 'Risk Level',
    'fields.riskDetected': 'risks detected',
    'fields.overview': 'Fields Overview',
    'fields.totalArea': 'Total Area',
    'fields.avgHealth': 'Avg. Health',

    // Add Field
    'addField.title': 'Add New Field',
    'addField.name': 'Field Name',
    'addField.namePlaceholder': 'e.g., Field A',
    'addField.location': 'Location',
    'addField.locationPlaceholder': 'Enter location or use map',
    'addField.markOnMap': 'Mark on Map',
    'addField.area': 'Area (Feddan)',
    'addField.areaPlaceholder': 'e.g., 2.5',
    'addField.cropType': 'Crop Type',
    'addField.selectCrop': 'Select crop type',
    'addField.soilType': 'Soil Type',
    'addField.selectSoil': 'Select soil type',
    'addField.irrigation': 'Irrigation Type',
    'addField.selectIrrigation': 'Select irrigation type',
    'addField.photo': 'Field Photo',
    'addField.takePhoto': 'Take a photo',
    'addField.submit': 'Add Field',
    'addField.successTitle': 'Field Added!',
    'addField.successMessage': 'Your new field has been added successfully',
    'addField.infoBanner':
        'Fill in the details about your field for better disease monitoring and forecasting.',

    // Crops
    'crops.wheat': 'Wheat',
    'crops.rice': 'Rice',
    'crops.corn': 'Corn',
    'crops.tomatoes': 'Tomatoes',
    'crops.potatoes': 'Potatoes',
    'crops.cotton': 'Cotton',
    'crops.onions': 'Onions',
    'crops.beans': 'Beans',
    'crops.other': 'Other',

    // Soil
    'soil.clay': 'Clay',
    'soil.sandy': 'Sandy',
    'soil.loamy': 'Loamy',
    'soil.silty': 'Silty',

    // Irrigation
    'irrigation.drip': 'Drip',
    'irrigation.sprinkler': 'Sprinkler',
    'irrigation.surface': 'Surface',
    'irrigation.manual': 'Manual',
    'irrigation.rainfed': 'Rainfed',

    // Forecast
    'forecast.title': 'Disease Forecasting',
    'forecast.currentRisk': 'Current Risk Level',
    'forecast.lowRisk': 'Low Risk',
    'forecast.moderateRisk': 'Moderate',
    'forecast.highRisk': 'High Risk',
    'forecast.riskTrend': '7-Day Risk Trend',

    // Reports
    'reports.title': 'Reports & Analytics',

    // Notifications
    'notifications.title': 'Notifications',
    'notifications.markAllRead': 'Mark all read',
    'notifications.today': 'Today',
    'notifications.earlier': 'Earlier',

    // Profile
    'profile.title': 'My Profile',
    'profile.accountSettings': 'Account Settings',
    'profile.subscription': 'Subscription',
    'profile.helpSupport': 'Help & Support',
    'profile.about': 'About AgriLens',
    'profile.logout': 'Log Out',

    // Settings
    'settings.title': 'Settings',
    'settings.account': 'Account',
    'settings.editProfile': 'Edit Profile',
    'settings.language': 'Language',
    'settings.notifications': 'Notifications',
    'settings.privacy': 'Privacy & Security',
    'settings.dataPrivacy': 'Data Privacy',
    'settings.termsConditions': 'Terms & Conditions',
    'settings.help': 'Help',
    'settings.tutorial': 'Tutorial',
    'settings.contactSupport': 'Contact Support',
    'settings.faq': 'FAQ',

    // Chat
    'chat.title': 'AgriBot',
    'chat.subtitle': 'Your farming assistant',
    'chat.greeting':
        'Hello! I\'m AgriBot 🌱 How can I help you with your farming today?',
    'chat.placeholder': 'Type your question...',
    'chat.tryAsking': 'Try asking me about:',
    'chat.question1': 'How to prevent tomato blight?',
    'chat.question2': 'Best fertilizer for wheat?',
    'chat.question3': 'When should I water my crops?',
    'chat.question4': 'How to improve soil quality?',

    // Subscription
    'subscription.title': 'Subscription',
    'subscription.premium': 'Premium Plan',
    'subscription.free': 'Free',
    'subscription.pro': 'Pro',
    'subscription.enterprise': 'Enterprise',
    'subscription.current': 'Current Plan',
    'subscription.upgrade': 'Upgrade Plan',
    'subscription.month': '/month',
    'subscription.features': 'Features',
    'subscription.payment': 'Payment',
    'subscription.cardNumber': 'Card Number',
    'subscription.expiry': 'Expiry Date',
    'subscription.cvv': 'CVV',
    'subscription.pay': 'Pay Now',
    'subscription.confirmTitle': 'Payment Successful!',
    'subscription.confirmMessage':
        'Your subscription has been activated successfully.',
    'subscription.manage': 'Manage Subscription',
    'subscription.cancelPlan': 'Cancel Plan',
    'subscription.renewDate': 'Renewal Date',
    'subscription.usage': 'Usage This Month',

    // Disease Map
    'diseaseMap.title': 'Disease Map',
    'diseaseMap.legend': 'Legend',
    'diseaseMap.noDisease': 'No Disease',
    'diseaseMap.lowRisk': 'Low Risk',
    'diseaseMap.moderateRisk': 'Moderate',
    'diseaseMap.highRisk': 'High Risk',
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
    'home.alerts': 'التنبيهات',
    'home.viewAll': 'عرض الكل',
    'home.moderateRisk': 'تم اكتشاف خطر متوسط',
    'home.treatmentComplete': 'اكتمل العلاج',
    'home.weatherToday': 'الطقس اليوم',
    'home.partlyCloudy': 'غائم جزئياً',
    'home.temp': 'درجة الحرارة',
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
    'disease.low': 'منخفض',
    'disease.high': 'مرتفع',

    // Nav
    'nav.home': 'الرئيسية',
    'nav.scan': 'الفحوصات',
    'nav.fields': 'الحقول',
    'nav.reports': 'التقارير',
    'nav.profile': 'الملف',

    // Fields
    'fields.title': 'حقولي',
    'fields.addNew': 'إضافة حقل جديد',
    'fields.viewMap': 'عرض الخريطة',
    'fields.healthy': 'صحي',
    'fields.warning': 'تحذير',
    'fields.area': 'المساحة',
    'fields.healthScore': 'نسبة الصحة',
    'fields.health': 'الصحة',
    'fields.riskLevel': 'مستوى الخطر',
    'fields.riskDetected': 'مخاطر مكتشفة',
    'fields.overview': 'نظرة عامة على الحقول',
    'fields.totalArea': 'المساحة الكلية',
    'fields.avgHealth': 'متوسط الصحة',

    // Add Field
    'addField.title': 'إضافة حقل جديد',
    'addField.name': 'اسم الحقل',
    'addField.namePlaceholder': 'مثال: الحقل أ',
    'addField.location': 'الموقع',
    'addField.locationPlaceholder': 'أدخل الموقع أو استخدم الخريطة',
    'addField.markOnMap': 'حدد على الخريطة',
    'addField.area': 'المساحة (فدان)',
    'addField.areaPlaceholder': 'مثال: 2.5',
    'addField.cropType': 'نوع المحصول',
    'addField.selectCrop': 'اختر نوع المحصول',
    'addField.soilType': 'نوع التربة',
    'addField.selectSoil': 'اختر نوع التربة',
    'addField.irrigation': 'نوع الري',
    'addField.selectIrrigation': 'اختر نوع الري',
    'addField.photo': 'صورة الحقل',
    'addField.takePhoto': 'التقط صورة',
    'addField.submit': 'إضافة الحقل',
    'addField.successTitle': 'تمت الإضافة!',
    'addField.successMessage': 'تم إضافة الحقل الجديد بنجاح',
    'addField.infoBanner':
        'أدخل تفاصيل حقلك لمراقبة أفضل للأمراض والتوقعات.',

    // Crops
    'crops.wheat': 'قمح',
    'crops.rice': 'أرز',
    'crops.corn': 'ذرة',
    'crops.tomatoes': 'طماطم',
    'crops.potatoes': 'بطاطس',
    'crops.cotton': 'قطن',
    'crops.onions': 'بصل',
    'crops.beans': 'فول',
    'crops.other': 'أخرى',

    // Soil
    'soil.clay': 'طينية',
    'soil.sandy': 'رملية',
    'soil.loamy': 'طميية',
    'soil.silty': 'غرينية',

    // Irrigation
    'irrigation.drip': 'تنقيط',
    'irrigation.sprinkler': 'رشاش',
    'irrigation.surface': 'سطحي',
    'irrigation.manual': 'يدوي',
    'irrigation.rainfed': 'مطري',

    // Forecast
    'forecast.title': 'توقعات الأمراض',
    'forecast.currentRisk': 'مستوى الخطر الحالي',
    'forecast.lowRisk': 'خطر منخفض',
    'forecast.moderateRisk': 'متوسط',
    'forecast.highRisk': 'خطر عالي',
    'forecast.riskTrend': 'اتجاه الخطر لـ 7 أيام',

    // Reports
    'reports.title': 'التقارير والتحليلات',

    // Notifications
    'notifications.title': 'الإشعارات',
    'notifications.markAllRead': 'تعيين الكل كمقروء',
    'notifications.today': 'اليوم',
    'notifications.earlier': 'سابقاً',

    // Profile
    'profile.title': 'ملفي الشخصي',
    'profile.accountSettings': 'إعدادات الحساب',
    'profile.subscription': 'الاشتراك',
    'profile.helpSupport': 'المساعدة والدعم',
    'profile.about': 'عن أجري لينس',
    'profile.logout': 'تسجيل الخروج',

    // Settings
    'settings.title': 'الإعدادات',
    'settings.account': 'الحساب',
    'settings.editProfile': 'تعديل الملف الشخصي',
    'settings.language': 'اللغة',
    'settings.notifications': 'الإشعارات',
    'settings.privacy': 'الخصوصية والأمان',
    'settings.dataPrivacy': 'خصوصية البيانات',
    'settings.termsConditions': 'الشروط والأحكام',
    'settings.help': 'المساعدة',
    'settings.tutorial': 'الدليل التعليمي',
    'settings.contactSupport': 'تواصل مع الدعم',
    'settings.faq': 'الأسئلة الشائعة',

    // Chat
    'chat.title': 'أجري بوت',
    'chat.subtitle': 'مساعدك الزراعي',
    'chat.greeting': 'مرحباً! أنا أجري بوت 🌱 كيف يمكنني مساعدتك في الزراعة اليوم؟',
    'chat.placeholder': 'اكتب سؤالك...',
    'chat.tryAsking': 'جرب أن تسألني عن:',
    'chat.question1': 'كيف أمنع لفحة الطماطم؟',
    'chat.question2': 'أفضل سماد للقمح؟',
    'chat.question3': 'متى يجب ري المحاصيل؟',
    'chat.question4': 'كيف أحسن جودة التربة؟',

    // Subscription
    'subscription.title': 'الاشتراك',
    'subscription.premium': 'الخطة المميزة',
    'subscription.free': 'مجاني',
    'subscription.pro': 'احترافي',
    'subscription.enterprise': 'مؤسسات',
    'subscription.current': 'الخطة الحالية',
    'subscription.upgrade': 'ترقية الخطة',
    'subscription.month': '/شهر',
    'subscription.features': 'المميزات',
    'subscription.payment': 'الدفع',
    'subscription.cardNumber': 'رقم البطاقة',
    'subscription.expiry': 'تاريخ الانتهاء',
    'subscription.cvv': 'CVV',
    'subscription.pay': 'ادفع الآن',
    'subscription.confirmTitle': 'تم الدفع بنجاح!',
    'subscription.confirmMessage': 'تم تفعيل اشتراكك بنجاح.',
    'subscription.manage': 'إدارة الاشتراك',
    'subscription.cancelPlan': 'إلغاء الخطة',
    'subscription.renewDate': 'تاريخ التجديد',
    'subscription.usage': 'الاستخدام هذا الشهر',

    // Disease Map
    'diseaseMap.title': 'خريطة الأمراض',
    'diseaseMap.legend': 'دليل الألوان',
    'diseaseMap.noDisease': 'لا مرض',
    'diseaseMap.lowRisk': 'خطر منخفض',
    'diseaseMap.moderateRisk': 'متوسط',
    'diseaseMap.highRisk': 'خطر عالي',
  };
}
