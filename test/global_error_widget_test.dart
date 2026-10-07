// Luoi an toan toan cuc (2026-10-06, audit toan app) — ep MOT WIDGET THAT nem exception trong
// build() (dung CHINH co che ErrorWidget cua Flutter, khong gia lap), xac nhan hien the loi va
// LUON co loi thoat: Navigator.canPop()==true -> "Quay lại"; ==false (lỗi ở trang gốc, không
// có gì để pop, vd trang gốc của 1 tab/shell route GoRouter) -> "Về trang chủ".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/core/utils/global_error_widget.dart';
import 'package:chinesemate/app/router/app_router.dart';

/// Nem exception THAT ngay trong build() — dung CHINH co che Flutter se kich hoat
/// ErrorWidget.builder (khong phai gia lap ket qua).
class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget();
  @override
  Widget build(BuildContext context) {
    throw Exception('Lỗi widget giả lập để test lưới an toàn toàn cục');
  }
}

void main() {
  late ErrorWidgetBuilder originalBuilder;

  setUp(() {
    originalBuilder = ErrorWidget.builder;
    ErrorWidget.builder = buildGlobalErrorWidget;
  });

  tearDown(() {
    ErrorWidget.builder = originalBuilder;
  });

  testWidgets('canPop = false (widget lỗi là route gốc) -> hiện thẻ lỗi + nút "Về trang chủ"',
      (tester) async {
    // flutter_test mac dinh coi BAT KY loi nao duoc bao qua FlutterError.onError la fail test
    // — ke ca loi da duoc CHINH Flutter bat va thay bang ErrorWidget (dung co che dang kiem
    // chung o day, khong phai loi that ngoai y muon). Tat NGAY TRONG than test (khong o
    // setUp — bi TestWidgetsFlutterBinding ghi de lai truoc khi than test chay), tu phuc hoi
    // qua FlutterError.onError = FlutterError.presentError sau khi xong (gia tri goc cua
    // binding nay, on dinh hon luu bien roi gan lai).
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {};
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(const MaterialApp(home: _ThrowingWidget()));
    await tester.pumpAndSettle();

    // Flutter tu bat exception trong build() va thay bang ErrorWidget — KHONG con la
    // "uncaught" o tang FlutterError toan cuc nua (day chinh la co che dang kiem chung).
    expect(find.text('Đã có lỗi hiển thị'), findsOneWidget);
    expect(find.text('Về trang chủ'), findsOneWidget);
    expect(find.text('Quay lại'), findsNothing);
  });

  testWidgets('canPop = true (widget lỗi được push lên trên 1 màn khác) -> hiện nút "Quay lại", bấm pop đúng',
      (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {};
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (ctx) => TextButton(
      onPressed: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const _ThrowingWidget())),
      child: const Text('open'),
    )))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Đã có lỗi hiển thị'), findsOneWidget);
    expect(find.text('Quay lại'), findsOneWidget);
    expect(find.text('Về trang chủ'), findsNothing);

    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget); // da pop ve dung man truoc, khong con ket
  });

  testWidgets('canPop = false -> bấm "Về trang chủ" gọi đúng onGoHome (không cần GoRouter thật trong test)',
      (tester) async {
    var wentHome = false;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      // Dung lai builder voi onGoHome tiem vao de khong phu thuoc appRouter THAT trong test.
      return buildGlobalErrorWidget(
        FlutterErrorDetails(exception: Exception('x')),
        onGoHome: () => wentHome = true,
      );
    })));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Về trang chủ'));
    expect(wentHome, isTrue);
  });

  testWidgets(
      'canPop = false, KHÔNG truyền onGoHome (hành vi thật ở production) -> bấm "Về trang chủ" điều hướng ĐÚNG bằng GoRouter tới /home',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: buildGlobalErrorWidget(FlutterErrorDetails(exception: Exception('x')))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Về trang chủ'));
    await tester.pumpAndSettle();

    // Khong gia lap gi — day la DUNG appRouter (GoRouter) that cua app, xac nhan onGoHome mac
    // dinh (khong override) goi dung appRouter.go('/home'), khong phai Navigator.push/pop
    // thong thuong hay 1 co che dieu huong khac. Doc qua routeInformationProvider (khong qua
    // .state, von can router THAT SU dang mount+khop route moi co du lieu — o day KHONG mount
    // appRouter that (SplashScreen co animation lap vo han, se lam pumpAndSettle treo), chi
    // can xac nhan go_router DA NHAN dung yeu cau dieu huong toi '/home'.
    expect(appRouter.routeInformationProvider.value.uri.path, '/home');
  });

  group('installGlobalErrorWidget (quyết định debug giữ mặc định / release gắn lưới an toàn)', () {
    testWidgets('debug = true -> GIỮ NGUYÊN ErrorWidget.builder hiện tại, không gán gì',
        (tester) async {
      // flutter_test TU KIEM TRA ErrorWidget.builder phai GIONG HET luc BAT DAU than test khi
      // KET THUC (truoc ca tearDown cua package:test) — nen phai tu khoi phuc lai trong CHINH
      // than test nay, khong dua vao tearDown o dau file (chay SAU kiem tra do).
      final atStart = ErrorWidget.builder; // = buildGlobalErrorWidget, da gan boi setUp() file nay
      Widget sentinel(FlutterErrorDetails d) => const SizedBox.shrink();
      ErrorWidget.builder = sentinel;

      installGlobalErrorWidget(debug: true);

      expect(ErrorWidget.builder, same(sentinel));
      expect(ErrorWidget.builder, isNot(same(buildGlobalErrorWidget)));

      ErrorWidget.builder = atStart;
    });

    testWidgets('debug = false -> gán đúng buildGlobalErrorWidget (bản release/profile)', (tester) async {
      installGlobalErrorWidget(debug: false); // setUp() da gan san buildGlobalErrorWidget -> no-op, van dung
      expect(ErrorWidget.builder, same(buildGlobalErrorWidget));
    });
  });
}
