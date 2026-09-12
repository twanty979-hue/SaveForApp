import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/widgets/split_list_card.dart';

void main() {
  testWidgets('SplitListCard in ListView with Spacer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              SplitListCard(
                height: 146,
                leadingColor: Colors.blue,
                accentColor: Colors.blue,
                icon: Icons.home,
                child: Column(
                  children: [
                    Text('Title'),
                    Spacer(),
                    Text('Bottom'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  });
}
