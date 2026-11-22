import 'package:flutter/material.dart';

/// Splits a list of items into two balanced columns (even indices on the left,
/// odd indices on the right) for side-by-side landscape masonry layouts without
/// vertical blank gaps when cards expand or collapse.
class MasonryTwoColumnGrid extends StatelessWidget {
  final List<Widget> children;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final EdgeInsetsGeometry padding;

  const MasonryTwoColumnGrid({
    super.key,
    required this.children,
    this.crossAxisSpacing = 12.0,
    this.mainAxisSpacing = 12.0,
    this.padding = EdgeInsets.zero,
  });

  /// Helper to split any list into two alternating columns `[leftCol, rightCol]`.
  static List<List<T>> splitColumns<T>(List<T> items) {
    final left = <T>[];
    final right = <T>[];
    for (int i = 0; i < items.length; i++) {
      if (i.isEven) {
        left.add(items[i]);
      } else {
        right.add(items[i]);
      }
    }
    return [left, right];
  }

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final cols = splitColumns<Widget>(children);
    final leftItems = cols[0];
    final rightItems = cols[1];

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacing(leftItems, mainAxisSpacing),
            ),
          ),
          SizedBox(width: crossAxisSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _withSpacing(rightItems, mainAxisSpacing),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _withSpacing(List<Widget> items, double spacing) {
    if (items.isEmpty) return const [];
    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }
}

/// Renders a scrollable 2-column paired row list for uniform or near-uniform cards
/// (such as Storage Pools, Physical Disks, and Installed TrueNAS Apps).
class UniformTwoColumnGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final ScrollPhysics? physics;

  const UniformTwoColumnGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.crossAxisSpacing = 12.0,
    this.mainAxisSpacing = 12.0,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final rowCount = (itemCount / 2).ceil();

    return ListView.separated(
      padding: padding,
      physics: physics,
      itemCount: rowCount,
      separatorBuilder: (_, __) => SizedBox(height: mainAxisSpacing),
      itemBuilder: (context, rowIndex) {
        final firstIndex = rowIndex * 2;
        final secondIndex = firstIndex + 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: itemBuilder(context, firstIndex)),
              SizedBox(width: crossAxisSpacing),
              Expanded(
                child: secondIndex < itemCount
                    ? itemBuilder(context, secondIndex)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
