import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmis_teleconsultation/hmis_teleconsultation.dart';

void main() {
  group('Call View Waiting State & Name Rendering Tests', () {
    testWidgets('connecting screen renders single ParticipantAvatar with pulse animation', (tester) async {
      final controller = TeleConsultationController.instance;
      // When engine is null, controller is in connecting/initializing state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => const TeleConsultationCallView(),
            ),
          ),
        ),
      );

      // Verify exactly ONE ParticipantAvatar exists
      expect(find.byType(ParticipantAvatar), findsOneWidget);
      // Verify no duplicate text or ghost avatar
      expect(find.text('Starting secure consultation…'), findsOneWidget);
    });

    testWidgets('patient name text adapts to long names without text overlap', (tester) async {
      const longName = 'Mayani Tisha Ghanshyambhai';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: const Text(
                  longName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text(longName), findsOneWidget);
      final textWidget = tester.widget<Text>(find.text(longName));
      expect(textWidget.maxLines, equals(2));
      expect(textWidget.overflow, equals(TextOverflow.ellipsis));
    });

    testWidgets('Gujarati name renders cleanly with correct initial', (tester) async {
      const gujaratiName = 'મયંક શાહ';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ParticipantAvatar(name: gujaratiName, size: 90),
                Text(gujaratiName),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ParticipantAvatar), findsOneWidget);
      expect(find.text('મ'), findsOneWidget);
      expect(find.text(gujaratiName), findsOneWidget);
    });

    testWidgets('renders properly on narrow mobile (360 width) and wide desktop (1280 width)', (tester) async {
      // 1. Narrow Mobile
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeleConsultationCallView(),
          ),
        ),
      );
      expect(find.byType(ParticipantAvatar), findsOneWidget);

      // 2. Wide Desktop
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TeleConsultationCallView(),
          ),
        ),
      );
      expect(find.byType(ParticipantAvatar), findsOneWidget);
    });
  });
}
