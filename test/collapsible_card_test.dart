import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nasdash/features/dashboard/presentation/widgets/collapsible_dashboard_card.dart';

void main() {
  testWidgets('CollapsibleDashboardCard renders and animates size on collapse/expand', (tester) async {
    bool collapsed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ListView(
                children: [
                  CollapsibleDashboardCard(
                    icon: Icons.speed,
                    title: 'Test Card',
                    summary: 'Test summary',
                    isCollapsed: collapsed,
                    onToggleCollapse: () {
                      setState(() {
                        collapsed = !collapsed;
                      });
                    },
                    child: Container(
                      height: 150,
                      color: Colors.blue,
                      child: const Text('Expanded Content'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Initial state: Expanded
    expect(find.text('Expanded Content'), findsOneWidget);
    final initialSize = tester.getSize(find.byType(CollapsibleDashboardCard));
    expect(initialSize.height, greaterThanOrEqualTo(150));

    // Tap top area to collapse
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    // Mid-animation check
    await tester.pump(const Duration(milliseconds: 100));
    final midSize = tester.getSize(find.byType(CollapsibleDashboardCard));
    expect(midSize.height, lessThan(initialSize.height));

    // Finish animation
    await tester.pumpAndSettle();
    expect(find.text('Test summary'), findsOneWidget);
    final collapsedSize = tester.getSize(find.byType(CollapsibleDashboardCard));
    expect(collapsedSize.height, lessThan(initialSize.height));

    // Tap to expand
    await tester.tap(find.text('Test summary'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midExpandSize = tester.getSize(find.byType(CollapsibleDashboardCard));
    expect(midExpandSize.height, greaterThan(collapsedSize.height));

    await tester.pumpAndSettle();
    expect(find.text('Expanded Content'), findsOneWidget);
  });
}
