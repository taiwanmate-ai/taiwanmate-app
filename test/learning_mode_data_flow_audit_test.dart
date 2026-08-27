/// learning_mode_data_flow_audit_test.dart — 2026-08-20.
///
/// AUDIT chuoi truyen du lieu learningMode (Phan B, yeu cau kiem chung
/// BANG CHUNG THAT — khong chi doc code): tu UI chon -> luu tru
/// (SharedPreferences that qua learning_mode_provider.dart) -> tham so
/// truyen vao buildSystemPromptV2 -> noi dung system_prompt CUOI CUNG
/// sinh ra. Moi buoc IN LOG gia tri thuc te de doi chieu bang mat
/// (`printOnFailure`/`print` — hien trong output test khi chay
/// `flutter test -r expanded`).
///
/// Dac biet kiem tra 2 CAP DE NHAM (yeu cau ro rang cua nguoi dung):
///   zh_vi vs zh_only — zh_vi PHAI co huong dan dich tieng Viet trong
///     ngoac, zh_only TUYET DOI KHONG duoc co.
///   en_vi vs en_only — tuong tu voi tieng Anh.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chinesemate/core/providers/learning_mode_provider.dart';
import 'package:chinesemate/features/chat/engines/companion_personality_engine.dart';

// Cau/cum tu DAC TRUNG dung de xac nhan co/khong co mat trong prompt —
// trich XUAT TRUC TIEP tu chinh source companion_personality_engine.dart
// (KHONG tu bia lai), de test that su doi chieu DUNG VAN BAN san xuat.
const _zhOnlyMarker = 'LANGUAGE: 繁體中文 ONLY. Zero Vietnamese. Zero English.';
const _enOnlyMarker = 'LANGUAGE: ENGLISH ONLY. Zero Vietnamese. Zero Chinese.';
const _zhViStartMarker = 'LANGUAGE: Every sentence MUST start in Traditional Chinese.';
const _enViStartMarker = 'LANGUAGE: Every sentence MUST start in English.';
const _viParentheticalMarker = 'Vietnamese is NEVER allowed as a standalone sentence — it may ONLY appear inside parentheses';
const _bilingualSelfCheckMarker = 'TỰ KIỂM TRA BẮT BUỘC TRƯỚC KHI GỬI';

String _buildPromptFor(String learningMode) {
  const engine = CompanionPersonalityEngine();
  final result = engine.buildSystemPromptV2(
    learningMode: learningMode,
    userType: 'student',
    sessionMessages: 3,
    mistakes: const [],
    userFrustrated: false,
    aiMemory: const {},
    nextAction: null,
    aiName: 'Yuki',
    aiGender: 'female',
    isVip: false,
    now: DateTime(2026, 8, 20, 10, 0),
    currentUserText: 'Xin chào',
    recentlySuggestedTrendPhraseIds: const {},
  );
  return result.prompt;
}

void main() {
  group('Buoc 1+2 — Luu tru THAT (SharedPreferences) qua learning_mode_provider.dart', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    for (final mode in kValidLearningModes) {
      test('setMode("$mode") -> loadLearningMode() doc lai DUNG gia tri "$mode", khong bi doi thanh gi khac', () async {
        final notifier = LearningModeNotifier();
        // Doi constructor's _load() (fire-and-forget, doc gia tri CU truoc
        // khi setMode()) on dinh TRUOC khi goi setMode() — tranh race giua
        // 2 thao tac SharedPreferences bat dong bo, dam bao assertion
        // duoi day phan anh DUNG hanh vi tuan tu that (UI luon cho
        // Notifier khoi tao xong truoc khi user co the bam chon).
        await Future<void>.delayed(Duration.zero);

        await notifier.setMode(mode);

        final reloaded = await loadLearningMode();
        // ignore: avoid_print
        print('[AUDIT Buoc 1] setMode("$mode") -> loadLearningMode() tra ve: "$reloaded"');
        expect(reloaded, mode, reason: 'Gia tri doc lai PHAI dung bang gia tri da luu, khong bi lech/doi');
        expect(notifier.state, mode, reason: 'State cua notifier (dung boi UI qua ref.watch) cung phai dung');
      });
    }

    test('Chua tung goi setMode() -> loadLearningMode() tra ve null (dung de Gate hien man hinh chon lan dau)', () async {
      final result = await loadLearningMode();
      // ignore: avoid_print
      print('[AUDIT Buoc 1] Chua chon gi -> loadLearningMode() tra ve: $result');
      expect(result, isNull);
    });

    test('Doi lien tiep qua CA 4 mode — moi lan doc lai deu dung, KHONG con sot gia tri cu', () async {
      final notifier = LearningModeNotifier();
      await Future<void>.delayed(Duration.zero);
      for (final mode in kValidLearningModes) {
        await notifier.setMode(mode);
        final reloaded = await loadLearningMode();
        // ignore: avoid_print
        print('[AUDIT Buoc 1] Doi sang "$mode" -> doc lai: "$reloaded"');
        expect(reloaded, mode);
      }
    });
  });

  group('Buoc 2+3 — Tham so truyen vao buildSystemPromptV2 + noi dung prompt CUOI CUNG', () {
    for (final mode in kValidLearningModes) {
      test('learningMode="$mode" -> prompt sinh ra chua DUNG marker dac trung cua mode nay', () {
        final prompt = _buildPromptFor(mode);
        // ignore: avoid_print
        print('[AUDIT Buoc 2] Goi buildSystemPromptV2(learningMode: "$mode")');
        // ignore: avoid_print
        print('[AUDIT Buoc 3] --- system_prompt CUOI CUNG (mode=$mode, ${prompt.length} ky tu) ---\n$prompt\n--- HET ---');

        switch (mode) {
          case 'zh_only':
            expect(prompt.contains(_zhOnlyMarker), isTrue, reason: 'Thieu marker zh_only');
            expect(prompt.contains(_viParentheticalMarker), isFalse, reason: 'zh_only KHONG duoc chua huong dan dich tieng Viet trong ngoac');
            expect(prompt.contains(_bilingualSelfCheckMarker), isFalse, reason: 'zh_only KHONG can tu kiem tra song ngu (chi 1 ngon ngu)');
            break;
          case 'en_only':
            expect(prompt.contains(_enOnlyMarker), isTrue, reason: 'Thieu marker en_only');
            expect(prompt.contains(_viParentheticalMarker), isFalse, reason: 'en_only KHONG duoc chua huong dan dich tieng Viet trong ngoac');
            expect(prompt.contains(_bilingualSelfCheckMarker), isFalse, reason: 'en_only KHONG can tu kiem tra song ngu');
            break;
          case 'zh_vi':
            expect(prompt.contains(_zhViStartMarker), isTrue, reason: 'Thieu marker zh_vi (bat dau bang tieng Trung)');
            expect(prompt.contains(_viParentheticalMarker), isTrue, reason: 'zh_vi PHAI co huong dan dich tieng Viet trong ngoac');
            expect(prompt.contains(_bilingualSelfCheckMarker), isTrue, reason: 'zh_vi PHAI co buoc tu kiem tra song ngu');
            break;
          case 'en_vi':
            expect(prompt.contains(_enViStartMarker), isTrue, reason: 'Thieu marker en_vi (bat dau bang tieng Anh)');
            expect(prompt.contains(_viParentheticalMarker), isTrue, reason: 'en_vi PHAI co huong dan dich tieng Viet trong ngoac');
            expect(prompt.contains(_bilingualSelfCheckMarker), isTrue, reason: 'en_vi PHAI co buoc tu kiem tra song ngu');
            break;
        }
      });
    }

    group('Buoc 6 — 2 CAP DE NHAM (yeu cau rieng cua nguoi dung, kiem tra ro rang KHONG lan)', () {
      test('zh_vi KHONG bi lan voi zh_only — zh_vi co huong dan dich Viet, zh_only thi KHONG', () {
        final zhVi = _buildPromptFor('zh_vi');
        final zhOnly = _buildPromptFor('zh_only');
        // ignore: avoid_print
        print('[AUDIT Buoc 6] zh_vi chua "$_viParentheticalMarker": ${zhVi.contains(_viParentheticalMarker)}');
        // ignore: avoid_print
        print('[AUDIT Buoc 6] zh_only chua "$_viParentheticalMarker": ${zhOnly.contains(_viParentheticalMarker)}');
        expect(zhVi.contains(_viParentheticalMarker), isTrue);
        expect(zhOnly.contains(_viParentheticalMarker), isFalse);
        expect(zhVi, isNot(equals(zhOnly)), reason: '2 mode PHAI sinh ra prompt khac nhau');
        expect(zhVi.contains(_zhOnlyMarker), isFalse, reason: 'Prompt zh_vi KHONG duoc lan marker rule cua zh_only');
        expect(zhOnly.contains(_zhViStartMarker), isFalse, reason: 'Prompt zh_only KHONG duoc lan marker rule cua zh_vi');
      });

      test('en_vi KHONG bi lan voi en_only — en_vi co huong dan dich Viet, en_only thi KHONG', () {
        final enVi = _buildPromptFor('en_vi');
        final enOnly = _buildPromptFor('en_only');
        // ignore: avoid_print
        print('[AUDIT Buoc 6] en_vi chua "$_viParentheticalMarker": ${enVi.contains(_viParentheticalMarker)}');
        // ignore: avoid_print
        print('[AUDIT Buoc 6] en_only chua "$_viParentheticalMarker": ${enOnly.contains(_viParentheticalMarker)}');
        expect(enVi.contains(_viParentheticalMarker), isTrue);
        expect(enOnly.contains(_viParentheticalMarker), isFalse);
        expect(enVi, isNot(equals(enOnly)));
        expect(enVi.contains(_enOnlyMarker), isFalse, reason: 'Prompt en_vi KHONG duoc lan marker rule cua en_only');
        expect(enOnly.contains(_enViStartMarker), isFalse, reason: 'Prompt en_only KHONG duoc lan marker rule cua en_vi');
      });

      test('Ca 4 mode sinh ra 4 prompt HOAN TOAN KHAC NHAU (khong co 2 mode nao vo tinh trung nhau)', () {
        final prompts = {for (final m in kValidLearningModes) m: _buildPromptFor(m)};
        for (final a in kValidLearningModes) {
          for (final b in kValidLearningModes) {
            if (a == b) continue;
            expect(prompts[a], isNot(equals(prompts[b])), reason: 'Prompt cua "$a" va "$b" khong duoc trung nhau');
          }
        }
      });
    });
  });
}
