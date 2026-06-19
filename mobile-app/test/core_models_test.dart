import 'package:agrilens/core/app_config.dart';
import 'package:agrilens/core/crop_provider.dart';
import 'package:agrilens/core/fields_provider.dart';
import 'package:agrilens/core/language_provider.dart';
import 'package:agrilens/core/notifications_provider.dart';
import 'package:agrilens/core/offline_sync_notification.dart';
import 'package:agrilens/core/scan_history_provider.dart';
import 'package:agrilens/core/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionStorage', () {
    test('saves, reads, and clears auth session', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SessionStorage();

      await storage.saveToken('token-123');
      await storage.saveUser({'id': 'user-1', 'name': 'Mona'});

      expect(await storage.readToken(), 'token-123');
      expect((await storage.readUser())?['name'], 'Mona');

      await storage.clearSession();

      expect(await storage.readToken(), isNull);
      expect(await storage.readUser(), isNull);
    });

    test('persists selected language independently from auth token', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SessionStorage();

      await storage.saveLanguage('ar');
      await storage.saveToken('token-123');
      await storage.clearToken();

      expect(await storage.readToken(), isNull);
      expect(await storage.readLanguage(), 'ar');
    });
  });

  group('FieldData', () {
    test('parses backend field JSON into display model', () {
      final field = FieldData.fromJson(
        {
          'field_id': 'field-1',
          'name': 'Plot A',
          'crop_type': 'tomato',
          'area_hectares': 2.75,
          'risk_level': 'medium',
          'health_score': 68.4,
          'location': {'label': 'Dakahlia', 'lat': '31.1', 'lng': 31.4},
          'weather_snapshot': {'source': 'fallback'},
        },
        farmId: 'farm-1',
        farmName: 'Main Farm',
      );

      expect(field.id, 'field-1');
      expect(field.farmId, 'farm-1');
      expect(field.location, 'Dakahlia');
      expect(field.status, 'warning');
      expect(field.health, 68);
      expect(field.latitude, 31.1);
      expect(field.longitude, 31.4);
      expect(field.weatherSnapshot['source'], 'fallback');
    });

    test('handles sparse field JSON safely', () {
      final field = FieldData.fromJson(
        {'name': 'Unnamed', 'location': 'No GPS'},
        farmId: 'farm-1',
        farmName: 'Main Farm',
      );

      expect(field.id, '');
      expect(field.location, 'No GPS');
      expect(field.area, '');
      expect(field.status, 'healthy');
      expect(field.latitude, isNull);
      expect(field.longitude, isNull);
    });
  });

  group('AppConfig', () {
    test('keeps absolute media urls and resolves relative uploads', () {
      expect(
        AppConfig.resolveMediaUrl('https://cdn.example/leaf.jpg'),
        'https://cdn.example/leaf.jpg',
      );

      final resolved = AppConfig.resolveMediaUrl('/uploads/leaf.jpg');

      expect(resolved, contains('/uploads/leaf.jpg'));
      expect(resolved, startsWith('http://'));
    });
  });

  group('CropProvider', () {
    test('includes icon-backed crop choices for new model crops', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = CropProvider();
      await Future<void>.delayed(Duration.zero);

      final values = CropProvider.crops.map((crop) => crop.value).toSet();

      expect(
        values,
        containsAll(['grape', 'wheat', 'corn', 'sugarcane', 'cotton']),
      );
      expect(values, isNot(contains('mushroom')));
      expect(CropProvider.crops.every((crop) => crop.emoji.isNotEmpty), isTrue);
      expect(
        CropProvider.crops
            .firstWhere((crop) => crop.value == 'sugarcane')
            .scanEnabled,
        isTrue,
      );

      await provider.selectCrop('sugarCane');

      expect(provider.selectedCrop, 'sugarcane');
      expect(provider.selectedCropInfo?.labelEn, 'Sugar Cane');
    });
  });

  group('ScanResult', () {
    test('parses selected video frame artifact urls', () {
      final scan = ScanResult.fromJson({
        'id': 'scan-1',
        'media_type': 'video',
        'media_url': 'https://cdn.example/video.mp4',
        'storage_backend': 'cloudinary',
        'status': 'completed',
        'detection_result': {
          'disease': 'Early blight',
          'confidence': 0.91,
          'severity': 'medium',
          'risk_level': 'medium',
          'is_healthy': false,
          'selected_frames': [
            {
              'frame_index': 4,
              'keyframe_score': 0.88,
              'frame_url': 'https://cdn.example/frame.jpg',
              'gradcam_url': 'https://cdn.example/gradcam.jpg',
              'display_url': 'https://cdn.example/gradcam.jpg',
              'disease': 'Early blight',
              'confidence': 0.91,
              'severity': 'medium',
              'risk_level': 'medium',
              'is_healthy': false,
            },
          ],
        },
      });

      expect(scan.isVideo, isTrue);
      expect(scan.selectedFrames, hasLength(1));
      expect(scan.selectedFrames.first.hasGradcam, isTrue);
      expect(
        scan.selectedFrames.first.displayUrl,
        'https://cdn.example/gradcam.jpg',
      );
    });
  });

  group('LanguageProvider', () {
    test('translates new crop labels, validation, and offline copy', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LanguageProvider();
      await provider.setLanguage('ar');

      expect(provider.t('crops.sugarCane'), 'قصب السكر');
      expect(provider.t('crops.grape'), 'عنب');
      expect(provider.t('scan.comingSoon'), 'قريباً');
      expect(
        provider.t('validation.cropMismatchTitle'),
        'المحصول المختار غير صحيح',
      );
      expect(provider.t('validation.uploadAnother'), 'رفع فحص آخر');
      expect(
        provider.t('offline.scanQueued'),
        'تم حفظ الفحص دون اتصال. ستتم مزامنته عند عودة الاتصال.',
      );
      expect(
        provider.t('offline.syncFailed'),
        'تعذر مزامنة بعض الفحوصات. ستتم إعادة المحاولة لاحقاً.',
      );
    });
  });

  group('NotificationData', () {
    test('keeps scan id for notification result navigation', () {
      final fromRelatedId = NotificationData.fromJson({
        'id': 'notification-1',
        'title': 'Scan complete',
        'message': 'Tap to view',
        'category': 'sync',
        'related_scan_id': 'scan-1',
      });
      final fromMetadata = NotificationData.fromJson({
        'id': 'notification-2',
        'title': 'Scan complete',
        'message': 'Tap to view',
        'metadata': {'scan_id': 'scan-2'},
      });

      expect(fromRelatedId.scanId, 'scan-1');
      expect(fromMetadata.scanId, 'scan-2');
    });

    test('adds offline sync notifications to the in-app list', () {
      final provider = NotificationsProvider();

      provider.addOfflineSyncNotification(
        OfflineSyncNotification(
          id: 'offline-scan-complete-scan-1',
          titleEn: 'Scan complete',
          titleAr: 'اكتمل الفحص',
          messageEn: 'Scan complete. No disease detected.',
          messageAr: 'اكتمل الفحص. لم يتم اكتشاف أي مرض.',
          scanId: 'scan-1',
        ),
      );

      expect(provider.notifications, hasLength(1));
      expect(provider.notifications.single.scanId, 'scan-1');
      expect(provider.notifications.single.titleAr, 'اكتمل الفحص');
      expect(provider.unreadCount, 1);
    });
  });
}
