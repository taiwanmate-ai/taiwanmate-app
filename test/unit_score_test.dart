// Điểm unit gửi lên /curriculum/unit/{id}/complete (Phase 1 "Học", 2026-09-26).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/learn/presentation/widgets/unit_practice_screen.dart';

void main() {
  group('unitScoreBody', () {
    test('chưa chấm câu nào -> null (không gửi điểm)', () {
      expect(unitScoreBody(0, 0), isNull);
      expect(unitScoreBody(3, -1), isNull);
    });

    test('điểm hợp lệ giữ nguyên', () {
      expect(unitScoreBody(7, 10), {'correct': 7, 'total': 10});
      expect(unitScoreBody(0, 4), {'correct': 0, 'total': 4});
    });

    test('correct vượt total / âm bị kẹp về [0, total] (server từ chối correct > total)', () {
      expect(unitScoreBody(12, 10), {'correct': 10, 'total': 10});
      expect(unitScoreBody(-2, 10), {'correct': 0, 'total': 10});
    });

    test('total > 50 (giới hạn server) được quy tỉ lệ về 50, giữ nguyên tỉ lệ đúng', () {
      final b = unitScoreBody(60, 80)!;
      expect(b['total'], 50);
      expect(b['correct'], 38); // 60/80 * 50 = 37.5 -> 38
      expect(b['correct']! <= b['total']!, isTrue);
    });
  });

  test('QuizScoreCounter đếm đúng/tổng', () {
    final c = QuizScoreCounter()..record(true)..record(false)..record(true);
    expect(c.correct, 2);
    expect(c.total, 3);
  });

  group('nối dây (bảo vệ chống hồi quy)', () {
    final src = File('lib/features/learn/presentation/widgets/unit_practice_screen.dart').readAsStringSync();
    final quizPart = src.substring(src.indexOf('return QuizTab('));
    final flashPart = src.substring(src.indexOf('return FlashcardTab('), src.indexOf('return QuizTab('));

    test('Quiz + Điền từ chấm điểm qua _scoredUpdateSRS', () {
      expect('_scoredUpdateSRS'.allMatches(quizPart).length, 2);
      expect(quizPart.contains('onUpdateSRS: widget.onUpdateSRS'), isFalse);
    });

    test('Flashcard (tự đánh giá) và Nghe KHÔNG tính vào điểm unit', () {
      expect(flashPart.contains('_scoredUpdateSRS'), isFalse);
    });

    test('curriculum_tab gửi điểm khi hoàn thành unit', () {
      final tab = File('lib/features/learn/presentation/widgets/curriculum_tab.dart').readAsStringSync();
      expect(tab.contains('onQuizScore: _onQuizScore'), isTrue);
      expect(tab.contains('data: score'), isTrue);
    });
  });
}
