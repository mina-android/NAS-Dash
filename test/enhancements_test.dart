import 'package:flutter_test/flutter_test.dart';
import 'package:nasdash/features/apps/models/app_model.dart';
import 'package:nasdash/features/dashboard/models/dashboard_widget_config.dart';

void main() {
  group('Enhancements & New Features Tests', () {
    test('TrueNasApp parses upgrade versions and app icons correctly', () {
      final json = {
        'id': 'plex',
        'name': 'plex',
        'state': 'RUNNING',
        'version': '1.40.5',
        'human_version': '1.40.5.8921',
        'upgrade_available': true,
        'upgrade_human_version': '1.41.0.8992',
        'upgrade_version': '1.41.0',
        'metadata': {
          'icon': 'https://truecharts.org/img/hotlink-ok/plex-logo.png',
        },
      };

      final app = TrueNasApp.fromJson(json);

      expect(app.name, equals('plex'));
      expect(app.isRunning, isTrue);
      expect(app.upgradeAvailable, isTrue);
      expect(app.version, equals('1.40.5'));
      expect(app.humanVersion, equals('1.40.5.8921'));
      expect(app.upgradeHumanVersion, equals('1.41.0.8992'));
      expect(app.upgradeVersion, equals('1.41.0'));
      expect(app.icon, equals('https://truecharts.org/img/hotlink-ok/plex-logo.png'));
    });

    test('DashboardWidgetConfig serializes and deserializes isCollapsed state', () {
      final config = DashboardWidgetConfig(
        type: DashboardWidgetType.memoryArc,
        isVisible: true,
        order: 4,
        size: WidgetCardSize.expanded,
        isCollapsed: true,
      );

      final map = config.toMap();
      expect(map['isCollapsed'], isTrue);

      final deserialized = DashboardWidgetConfig.fromMap(map);
      expect(deserialized.type, equals(DashboardWidgetType.memoryArc));
      expect(deserialized.isCollapsed, isTrue);
      expect(deserialized.isVisible, isTrue);
      expect(deserialized.order, equals(4));

      final toggled = deserialized.copyWith(isCollapsed: false);
      expect(toggled.isCollapsed, isFalse);
    });
  });
}
