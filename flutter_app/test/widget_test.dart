import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homelink/main.dart';

void main() {
  testWidgets('HomeLink uses Ocean Blue theme', (tester) async {
    await tester.pumpWidget(const HomeLinkApp());
    final app=tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title,'HomeLink');
    expect(app.theme?.colorScheme.primary,const Color(0xFF123C69));
  });
}
