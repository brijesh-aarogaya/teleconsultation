import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmis_teleconsultation/hmis_teleconsultation.dart';

void main() {
  group('ParticipantAvatar Grapheme & Initial Tests', () {
    test('extractInitial handles English names', () {
      expect(ParticipantAvatar.extractInitial('Mayani Tisha'), equals('M'));
      expect(ParticipantAvatar.extractInitial('john doe'), equals('J'));
    });

    test('extractInitial handles trimmed leading and trailing spaces', () {
      expect(ParticipantAvatar.extractInitial('   Dr. Smith   '), equals('D'));
      expect(ParticipantAvatar.extractInitial('  Alice'), equals('A'));
    });

    test('extractInitial handles empty and null names safely', () {
      expect(ParticipantAvatar.extractInitial(''), equals('?'));
      expect(ParticipantAvatar.extractInitial('   '), equals('?'));
      expect(ParticipantAvatar.extractInitial(null), equals('?'));
    });

    test('extractInitial handles non-Latin scripts (Gujarati and Hindi)', () {
      // Gujarati name: મયંક (Mayank) -> first grapheme cluster 'મ'
      expect(ParticipantAvatar.extractInitial('મયંક શાહ'), equals('મ'));
      // Hindi name: राहुल (Rahul) -> first grapheme cluster is consonant + vowel matra 'रा'
      expect(ParticipantAvatar.extractInitial('राहुल शर्मा'), equals('रा'));
    });

    test('extractInitial handles accented Latin characters', () {
      expect(ParticipantAvatar.extractInitial('Éléonore'), equals('É'));
      expect(ParticipantAvatar.extractInitial('álvarez'), equals('Á'));
    });

    testWidgets('renders avatar with correct initial in widget tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ParticipantAvatar(name: 'Mayani Tisha', size: 80),
          ),
        ),
      );

      expect(find.byType(ParticipantAvatar), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('renders Gujarati initial properly in widget tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ParticipantAvatar(name: 'મયંક શાહ', size: 80),
          ),
        ),
      );

      expect(find.byType(ParticipantAvatar), findsOneWidget);
      expect(find.text('મ'), findsOneWidget);
    });
  });
}
