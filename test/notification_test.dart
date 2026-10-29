import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nasdash/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Alert Deduplication Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Alert is not seen initially', () async {
      final seen = await NotificationService.instance.hasAlertBeenSeen('alert-uuid-1234');
      expect(seen, isFalse);
    });

    test('Marking alert seen prevents repeated notification', () async {
      const uuid = 'alert-uuid-1234';
      await NotificationService.instance.markAlertSeen(uuid);
      final seen = await NotificationService.instance.hasAlertBeenSeen(uuid);
      expect(seen, isTrue);
    });

    test('Different alert UUIDs are tracked independently', () async {
      await NotificationService.instance.markAlertSeen('alert-1');
      expect(await NotificationService.instance.hasAlertBeenSeen('alert-1'), isTrue);
      expect(await NotificationService.instance.hasAlertBeenSeen('alert-2'), isFalse);
    });
  });
}
