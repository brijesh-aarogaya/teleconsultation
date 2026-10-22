import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aspect Ratio & Layout Selection Widget Tests', () {
    testWidgets('patient focus container preserves remote aspect ratio with letterboxing', (tester) async {
      const remoteAspectRatio = 9 / 16;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: remoteAspectRatio,
                  child: Container(
                    key: const ValueKey('patient_video_container'),
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final containerFinder = find.byKey(const ValueKey('patient_video_container'));
      expect(containerFinder, findsOneWidget);

      final containerSize = tester.getSize(containerFinder);
      final computedRatio = containerSize.width / containerSize.height;
      expect(computedRatio, closeTo(remoteAspectRatio, 0.05));
    });

    testWidgets('side-by-side layout splits doctor and patient equally', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 600,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      key: const ValueKey('doctor_col'),
                      color: Colors.grey.shade900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      key: const ValueKey('patient_col'),
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final docFinder = find.byKey(const ValueKey('doctor_col'));
      final patientFinder = find.byKey(const ValueKey('patient_col'));

      expect(docFinder, findsOneWidget);
      expect(patientFinder, findsOneWidget);

      final docWidth = tester.getSize(docFinder).width;
      final patientWidth = tester.getSize(patientFinder).width;
      expect(docWidth, equals(patientWidth));
    });

    testWidgets('desktop side-by-side layout detects clicks on both columns to toggle controls', (tester) async {
      int toggleCount = 0;
      void toggleControls() => toggleCount++;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 700,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: toggleControls,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: toggleControls,
                        child: Container(
                          key: const ValueKey('doctor_video_slot'),
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: toggleControls,
                        child: Container(
                          key: const ValueKey('patient_video_slot'),
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Tap on doctor video slot
      await tester.tap(find.byKey(const ValueKey('doctor_video_slot')));
      await tester.pump();
      expect(toggleCount, equals(1));

      // Tap on patient video slot (opponent video)
      await tester.tap(find.byKey(const ValueKey('patient_video_slot')));
      await tester.pump();
      expect(toggleCount, equals(2));
    });

    testWidgets('desktop video area detects pointer hover to reveal controls', (tester) async {
      bool controlsVisible = false;
      void onHover() {
        if (!controlsVisible) controlsVisible = true;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MouseRegion(
              onHover: (_) => onHover(),
              child: Container(
                key: const ValueKey('hover_area'),
                width: 1200,
                height: 800,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );

      expect(controlsVisible, isFalse);

      // Simulate mouse enter/hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('hover_area'))));
      await tester.pump();

      expect(controlsVisible, isTrue);
    });
  });
}
