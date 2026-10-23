import 'package:flutter_test/flutter_test.dart';
import 'package:deadland/main.dart';

void main() {
  testWidgets('Main menu builds', (tester) async {
    await tester.pumpWidget(const DeadlandApp());
    await tester.pump();
    expect(find.text('بقا در مرگ'), findsOneWidget);
    expect(find.text('بازمانده‌ی جدید'), findsOneWidget);
    expect(find.text('شخصیت‌ها'), findsOneWidget);
    expect(find.text('فروشگاه'), findsOneWidget);
    expect(find.text('تنظیمات'), findsOneWidget);
  });
}
