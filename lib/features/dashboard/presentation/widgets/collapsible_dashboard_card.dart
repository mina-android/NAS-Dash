import 'package:flutter/material.dart';
import '../../../../core/widgets/glass_card.dart';

class CollapsibleDashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String summary;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final Widget child;

  const CollapsibleDashboardCard({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final collapsedWidget = GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggleCollapse,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final expandedWidget = Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 46,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onToggleCollapse,
          ),
        ),
      ],
    );

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.fastOutSlowIn,
          alignment: Alignment.topCenter,
          child: KeyedSubtree(
            key: ValueKey<bool>(isCollapsed),
            child: isCollapsed ? collapsedWidget : expandedWidget,
          ),
        ),
      ),
    );
  }
}
