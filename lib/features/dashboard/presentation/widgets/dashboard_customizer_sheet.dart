import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_layout_provider.dart';

class DashboardCustomizerSheet extends ConsumerWidget {
  const DashboardCustomizerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(dashboardLayoutProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customize Dashboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drag to reorder and toggle widget visibility',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => ref.read(dashboardLayoutProvider.notifier).resetToDefaults(),
                  child: Text('Reset', style: TextStyle(color: colorScheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: widgets.length,
                onReorderItem: (oldIndex, newIndex) {
                  ref.read(dashboardLayoutProvider.notifier).reorder(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final item = widgets[index];

                  return Container(
                    key: ValueKey(item.type),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.drag_indicator,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      title: Text(
                        item.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: item.isVisible ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Switch(
                        value: item.isVisible,
                        activeThumbColor: colorScheme.primary,
                        onChanged: (val) {
                          ref.read(dashboardLayoutProvider.notifier).toggleVisibility(item.type);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
