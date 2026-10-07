// Bug cung loai voi grammar_tool_screen.dart (2026-10-06, xem audit toan app): AI tra JSON
// cho /translate/grammar-text cung chi dam bao hop le CU PHAP, khong dam bao DUNG SCHEMA —
// "structure"/"grammar_points"/"vocab_breakdown" co the la List<String> thay vi dung
// List<Map{...}>, gay crash trong build() cua tools_screen.dart::_buildGrammarCard() (cu).
// parseGrammarAnalysisData()/buildGrammarAnalysisSection() la ham THUAN cap top-level (tach
// khoi ToolsScreen de test duoc truc tiep, khong can dung ca man hinh/mang/OCR).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/tools/presentation/screens/tools_screen.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('parseGrammarAnalysisData (thuan tuy, khong can widget)', () {
    test('dung schema giu nguyen noi dung', () {
      final r = parseGrammarAnalysisData({
        'sentence': '我吃飯。', 'has_error': false, 'pinyin': 'wǒ chī fàn', 'meaning': 'Tôi ăn cơm.',
        'structure': [{'part': '我', 'role': 'Chủ ngữ', 'meaning': 'tôi'}],
        'grammar_points': [{'title': 'Câu đơn', 'explanation': 'Giải thích', 'formula': 'S+V+O'}],
        'vocab_breakdown': [{'word': '吃', 'pinyin': 'chī', 'meaning': 'ăn'}],
      });
      expect(r['sentence'], '我吃飯。');
      expect(r['structure'], [{'part': '我', 'role': 'Chủ ngữ', 'meaning': 'tôi'}]);
      expect(r['grammar_points'], [{'title': 'Câu đơn', 'explanation': 'Giải thích', 'formula': 'S+V+O'}]);
      expect(r['vocab_breakdown'], [{'word': '吃', 'pinyin': 'chī', 'meaning': 'ăn'}]);
    });

    test('structure/grammar_points/vocab_breakdown là List<String> (bug thật đã xác nhận) -> chuyển đúng dạng, không crash', () {
      final r = parseGrammarAnalysisData({
        'sentence': 'test',
        'structure': ['我 (chủ ngữ)'],
        'grammar_points': ['Thì hiện tại'],
        'vocab_breakdown': ['吃飯'],
      });
      expect(r['structure'], [{'part': '我 (chủ ngữ)', 'role': '', 'meaning': ''}]);
      expect(r['grammar_points'], [{'title': 'Thì hiện tại', 'explanation': '', 'formula': ''}]);
      expect(r['vocab_breakdown'], [{'word': '吃飯', 'pinyin': '', 'meaning': ''}]);
    });

    test('phần tử rỗng/sai kiểu bị loại, không làm vỡ cả danh sách', () {
      final r = parseGrammarAnalysisData({
        'structure': [{'part': 'ok', 'role': 'r', 'meaning': 'm'}, '', null, 123, {'role': 'thiếu part'}],
      });
      expect(r['structure'], [{'part': 'ok', 'role': 'r', 'meaning': 'm'}]);
    });

    test('field đơn sai kiểu được stringify, không crash', () {
      final r = parseGrammarAnalysisData({'sentence': 123, 'pinyin': null, 'has_error': 'yes'});
      expect(r['sentence'], '123');
      expect(r['pinyin'], '');
      expect(r['has_error'], false); // 'yes' != true (dung) -> an toan, khong doan nham la true
    });

    test('list không phải List (vd 1 chuỗi trần) -> trả rỗng, không crash', () {
      final r = parseGrammarAnalysisData({'structure': 'không phải list'});
      expect(r['structure'], isEmpty);
    });

    test('thiếu toàn bộ field -> schema rỗng hợp lệ', () {
      final r = parseGrammarAnalysisData({});
      expect(r['sentence'], '');
      expect(r['structure'], isEmpty);
      expect(r['grammar_points'], isEmpty);
      expect(r['vocab_breakdown'], isEmpty);
    });
  });

  group('buildGrammarAnalysisSection (widget) — không bao giờ throw', () {
    testWidgets('dữ liệu lệch schema thật (List<String>) -> không crash, vẫn hiện nội dung', (tester) async {
      await tester.pumpWidget(_host(buildGrammarAnalysisSection({
        'sentence': '他把門關上了。', 'meaning': 'Anh ấy đóng cửa lại.',
        'structure': ['他 (chủ ngữ)', '把門關上 (vị ngữ)'],
      })));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('他把門關上了。'), findsOneWidget);
      expect(find.text('他 (chủ ngữ)'), findsOneWidget); // van HIEN noi dung, khong am tham bo
    });

    testWidgets('dữ liệu hoàn toàn rỗng {} -> không crash', (tester) async {
      await tester.pumpWidget(_host(buildGrammarAnalysisSection(<String, dynamic>{})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('đúng schema -> hiện đầy đủ, hành vi cũ không đổi', (tester) async {
      await tester.pumpWidget(_host(buildGrammarAnalysisSection({
        'sentence': '我吃飯。', 'has_error': false, 'pinyin': 'wǒ chī fàn', 'meaning': 'Tôi ăn cơm.',
        'structure': [{'part': '我', 'role': 'Chủ ngữ', 'meaning': 'tôi'}],
        'grammar_points': [{'title': 'Câu đơn', 'explanation': 'Giải thích ABC', 'formula': 'S+V+O'}],
        'vocab_breakdown': [{'word': '吃', 'pinyin': 'chī', 'meaning': 'ăn'}],
      })));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('我吃飯。'), findsOneWidget);
      expect(find.text('Giải thích ABC'), findsOneWidget);
      expect(find.text('S+V+O'), findsOneWidget);
    });
  });
}
