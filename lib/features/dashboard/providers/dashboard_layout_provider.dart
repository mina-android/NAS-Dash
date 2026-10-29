import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_widget_config.dart';

const String _kDashboardLayoutPrefsKey = 'nas_dash_dashboard_layout_v1';

final dashboardLayoutProvider =
    StateNotifierProvider<DashboardLayoutNotifier, List<DashboardWidgetConfig>>((ref) {
  return DashboardLayoutNotifier();
});

class DashboardLayoutNotifier extends StateNotifier<List<DashboardWidgetConfig>> {
  DashboardLayoutNotifier() : super(_defaultLayout()) {
    _loadLayout();
  }

  static List<DashboardWidgetConfig> _defaultLayout() {
    return [
      DashboardWidgetConfig(type: DashboardWidgetType.systemSummary, isVisible: true, order: 0),
      DashboardWidgetConfig(type: DashboardWidgetType.cpuUsage, isVisible: true, order: 1),
      DashboardWidgetConfig(type: DashboardWidgetType.cpuTemp, isVisible: true, order: 2),
      DashboardWidgetConfig(type: DashboardWidgetType.gpuStatus, isVisible: true, order: 3),
      DashboardWidgetConfig(type: DashboardWidgetType.memoryArc, isVisible: true, order: 4),
      DashboardWidgetConfig(type: DashboardWidgetType.storagePools, isVisible: true, order: 5),
      DashboardWidgetConfig(type: DashboardWidgetType.diskHealthIo, isVisible: true, order: 6),
      DashboardWidgetConfig(type: DashboardWidgetType.networkTraffic, isVisible: true, order: 7),
      DashboardWidgetConfig(type: DashboardWidgetType.appsUsage, isVisible: true, order: 8),
      DashboardWidgetConfig(type: DashboardWidgetType.alertsJobs, isVisible: true, order: 9),
      DashboardWidgetConfig(type: DashboardWidgetType.sharesServices, isVisible: true, order: 10),
      DashboardWidgetConfig(type: DashboardWidgetType.upsStatus, isVisible: false, order: 11),
    ];
  }

  Future<void> _loadLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kDashboardLayoutPrefsKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = json.decode(raw);
        final loaded = decoded.map((e) => DashboardWidgetConfig.fromMap(e as Map<String, dynamic>)).toList();
        // Ensure any newly added enum widgets exist
        final existingTypes = loaded.map((e) => e.type).toSet();
        for (final def in _defaultLayout()) {
          if (!existingTypes.contains(def.type)) {
            loaded.add(def.copyWith(order: loaded.length));
          }
        }
        loaded.sort((a, b) => a.order.compareTo(b.order));
        state = loaded;
      }
    } catch (_) {}
  }

  Future<void> _saveLayout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = json.encode(state.map((e) => e.toMap()).toList());
      await prefs.setString(_kDashboardLayoutPrefsKey, raw);
    } catch (_) {}
  }

  void reorder(int oldIndex, int newIndex) {
    var index = newIndex;
    if (oldIndex < index) {
      index -= 1;
    }
    final items = List<DashboardWidgetConfig>.from(state);
    final item = items.removeAt(oldIndex);
    items.insert(index, item);
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(order: i);
    }
    state = items;
    _saveLayout();
  }

  void toggleVisibility(DashboardWidgetType type) {
    state = state.map((item) {
      if (item.type == type) {
        return item.copyWith(isVisible: !item.isVisible);
      }
      return item;
    }).toList();
    _saveLayout();
  }

  void toggleCardSize(DashboardWidgetType type) {
    state = state.map((item) {
      if (item.type == type) {
        final next = item.size == WidgetCardSize.expanded
            ? WidgetCardSize.compact
            : WidgetCardSize.expanded;
        return item.copyWith(size: next);
      }
      return item;
    }).toList();
    _saveLayout();
  }

  void toggleCollapsed(DashboardWidgetType type) {
    state = state.map((item) {
      if (item.type == type) {
        return item.copyWith(isCollapsed: !item.isCollapsed);
      }
      return item;
    }).toList();
    _saveLayout();
  }

  void resetToDefaults() {
    state = _defaultLayout();
    _saveLayout();
  }
}
