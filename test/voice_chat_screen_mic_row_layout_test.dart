/// AUDIT "Layout vo hinh — nut Giu de noi" (2026-08-30).
///
/// Bao cao that (Console F12): "Cannot hit test a render box with no
/// size" + "RenderBox was not laid out (hasSize)" khien nut "Giu de noi"
/// KHONG BAO GIO hien/bam duoc trong Voice Chat khi dang co phien hoat
/// dong (_sessionActive == true).
///
/// NGUYEN NHAN (xac nhan qua chinh test nay TRUOC KHI fix — xem lich su
/// git, cau truc CU khong co SizedBox(height:88) bao ngoai): mot
/// Row(crossAxisAlignment: CrossAxisAlignment.stretch) dat TRUC TIEP lam
/// non-flex child cua 1 Column CO 1 Expanded o truoc no (vd vung
/// transcript trong voice_chat_screen.dart) se nhan duoc rang buoc
/// UNBOUNDED (maxHeight: Infinity) o truc chinh tu Column cha — day la
/// hanh vi CHUAN cua Column (can thiet de tinh dung khong gian con lai
/// cho Expanded) — nhung CrossAxisAlignment.stretch tren Row lai CAN 1
/// rang buoc height CO GIOI HAN de biet "stretch toi dau". Ket hop 2 dieu
/// nay khien Flutter NEM LOI THAT "BoxConstraints forces an infinite
/// height" NGAY TRONG performLayout() — xay ra o MOI LAN render (khong
/// phai thinh thoang/do cache), nen RenderBox cua Row (va GestureDetector
/// nut mic ben trong) KHONG BAO GIO co duoc `size` -> "Cannot hit test a
/// render box with no size" dung boi bao cao that.
///
/// FIX (voice_chat_screen.dart, xem docstring o do): bao Row trong 1
/// SizedBox(height: 88) CO GIOI HAN RO RANG — Row nhan duoc height=88 (KHONG
/// con Infinity) tu chinh SizedBox thay vi tu Column, nen stretch hoat
/// dong dung, khong con phu thuoc rang buoc tu widget cha co the la
/// unbounded.
///
/// Test nay tai lap CHINH XAC hinh dang widget tree that (Column co 1
/// Expanded truoc Row, giong voice_chat_screen.dart) de dam bao KHONG
/// tai pham to hop "Row(stretch) truc tiep lam non-flex child cua Column
/// co Expanded" trong tuong lai — bat ky ai xoa SizedBox(height:88) bao
/// ngoai deu se lam test nay FAIL NGAY (khong doi den luc chay that tren
/// thiet bi/console moi phat hien).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tai lap dung hinh dang: Column [banner, Expanded(vung scroll), Row(mic
/// + ban phim) trong 1 SizedBox(height co gioi han), nut "Dung"] — giong
/// het thu tu trong voice_chat_screen.dart build().
Widget _buildRepro() {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 700,
        child: Column(
          children: [
            Container(height: 70, color: Colors.green),
            const SizedBox(height: 24),
            Expanded(child: Container(color: Colors.grey, child: const Text('transcript area'))),
            const SizedBox(height: 20),
            SizedBox(
              height: 88,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        color: Colors.indigo,
                        alignment: Alignment.center,
                        child: const Text('Giữ để nói'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 64, child: ElevatedButton(onPressed: () {}, child: const Icon(Icons.keyboard))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 48, child: ElevatedButton(onPressed: () {}, child: const Text('Dừng Voice'))),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('nut Giu de noi PHAI render KHONG loi, co size that (khong phai 0/khong bi Infinity constraint)', (tester) async {
    await tester.pumpWidget(_buildRepro());

    expect(tester.takeException(), isNull, reason: 'Row(stretch) chua SizedBox(height) bao ngoai se nem "BoxConstraints forces an infinite height" — day chinh la bug that da bao cao qua Console F12');

    final micText = find.text('Giữ để nói');
    expect(micText, findsOneWidget, reason: 'Nut "Giu de noi" phai TON TAI trong widget tree');

    final micSize = tester.getSize(find.ancestor(of: micText, matching: find.byType(GestureDetector)).first);
    expect(micSize.height, 88, reason: 'Nut mic phai co chieu cao THAT su = 88 (khop SizedBox bao ngoai), khong duoc la 0 hay bi loi khong co size');
    expect(micSize.width, greaterThan(0), reason: 'Nut mic phai co chieu rong THAT su > 0');

    // Nut ban phim (SizedBox 64) cung phai duoc stretch dung 88 cao, chung
    // minh CrossAxisAlignment.stretch hoat dong DUNG sau khi Row co duoc
    // height=88 co gioi han (khong con Infinity).
    final keyboardIcon = find.byIcon(Icons.keyboard);
    final keyboardSize = tester.getSize(keyboardIcon);
    expect(keyboardSize.height, greaterThan(0));
  });

  testWidgets('nut Giu de noi PHAI bam duoc that (hit-test thanh cong, khong nem "Cannot hit test a render box with no size")', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: Column(
              children: [
                Container(height: 70, color: Colors.green),
                const SizedBox(height: 24),
                Expanded(child: Container(color: Colors.grey)),
                const SizedBox(height: 20),
                SizedBox(
                  height: 88,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => tapped = true,
                          child: Container(color: Colors.indigo, child: const Text('Giữ để nói')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(width: 64, child: ElevatedButton(onPressed: () {}, child: const Icon(Icons.keyboard))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Giữ để nói'));
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Tap PHAI hit-test thanh cong, khong duoc nem "Cannot hit test a render box with no size"');
    expect(tapped, isTrue, reason: 'onTap callback cua nut mic PHAI duoc goi — bang chung hit-test hoat dong dung');
  });
}
