import 'package:debt_ledger/presentation/widgets/item_actions_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required List<ItemAction> Function(BuildContext) actions,
}) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showItemActionsOverlay(
            context,
            anchor: const Rect.fromLTWH(20, 300, 320, 72),
            anchorPreview: const SizedBox(),
            actions: actions(context),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders a button per action and fires its callback on tap',
      (tester) async {
    var edited = 0;
    var deleted = 0;

    await tester.pumpWidget(_host(
      actions: (_) => [
        ItemAction(icon: Icons.edit, label: 'Edit', onSelected: () => edited++),
        ItemAction(
            icon: Icons.delete, label: 'Delete', onSelected: () => deleted++),
      ],
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(deleted, 1);
    expect(edited, 0);
    // Overlay dismissed after choosing an action.
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets('tapping the scrim dismisses without acting', (tester) async {
    var fired = 0;

    await tester.pumpWidget(_host(
      actions: (_) => [
        ItemAction(icon: Icons.edit, label: 'Edit', onSelected: () => fired++),
      ],
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit), findsOneWidget);

    // Empty corner = scrim, not a button.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit), findsNothing);
    expect(fired, 0);
  });
}
