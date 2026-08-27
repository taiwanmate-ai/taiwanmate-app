import 'package:flutter_test/flutter_test.dart';
import 'package:chinesemate/features/chat/engines/voice_activity_detector.dart';

void main() {
  // Dung 1 moc thoi gian gia lap co dinh (khong dung DateTime.now() that —
  // tranh test flaky do timing may that).
  final base = DateTime(2026, 8, 15, 10, 0, 0);
  DateTime t(int ms) => base.add(Duration(milliseconds: ms));

  group('VoiceActivityDetector — A1 Adaptive noise floor', () {
    test('Tinh noise floor la MEDIAN cac mau trong 500ms dau, KHONG danh gia speech trong luc calibrate', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      // 5 mau trong calibration window (500ms dau) — median cua
      // [-58,-56,-55,-54,-50] (sau khi sap xep) = -55.
      expect(vad.processAmplitude(-58, t(50)), isNull);
      expect(vad.processAmplitude(-56, t(150)), isNull);
      expect(vad.processAmplitude(-50, t(250)), isNull);
      expect(vad.processAmplitude(-54, t(350)), isNull);
      expect(vad.processAmplitude(-55, t(450)), isNull);
      expect(vad.noiseFloorDb, isNull, reason: 'Chua qua het calibration window');

      // Frame dau tien TU t(500) tro di kich hoat tinh calibration.
      vad.processAmplitude(-55, t(500));
      expect(vad.noiseFloorDb, -55.0);
      expect(vad.currentStartThresholdDb, -40.0); // -55 + startMarginDb(15)
      expect(vad.currentStopThresholdDb, -47.0); // -40 - (15 - stopMarginDb(8))
    });

    test('Khong co mau nao trong calibration window -> fallback an toan qua minAbsoluteStartThresholdDb', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      // Goi processAmplitude() LAN DAU TIEN da o SAU calibration window —
      // khong co mau nao duoc thu thap.
      vad.processAmplitude(-55, t(600));
      // fallback: noiseFloor = minAbsoluteStartThresholdDb(-50) - startMarginDb(15) = -65
      // startThreshold = max(-65+15, -50) = -50 (bi clamp boi san an toan).
      expect(vad.currentStartThresholdDb, -50.0);
    });

    test('Noise floor CHI tinh 1 LAN dau phien — KHONG tinh lai giua cac luot noi trong CUNG 1 phien', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      vad.processAmplitude(-55, t(500));
      final floorSauCalibrate = vad.noiseFloorDb;
      expect(floorSauCalibrate, isNotNull);

      // Du moi truong "on ao hon" sau do (vd -30dB lien tuc, gia lap
      // nhieu nen tang len giua chung) — noise floor KHONG duoc tinh lai
      // tu dong trong cung 1 phien (calibration la 1-lan-dau-phien, xem
      // docstring class).
      for (var i = 0; i < 20; i++) {
        vad.processAmplitude(-30, t(600 + i * 30));
      }
      expect(vad.noiseFloorDb, floorSauCalibrate);
    });
  });

  group('VoiceActivityDetector — A3 Consecutive speech frames', () {
    test('1 frame don le vuot nguong (spike) KHONG du de xac nhan speechStarted', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms)); // calibration, noise floor ~ -55
      }
      // 1 frame vuot nguong (-40) roi ve lai im lang ngay — spike don le.
      expect(vad.processAmplitude(-20, t(500)), isNull);
      expect(vad.processAmplitude(-55, t(530)), isNull);
      expect(vad.state, VadState.idle);
    });

    test('Du 3 frame LIEN TIEP vuot nguong -> xac nhan speechStarted DUNG 1 LAN', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      expect(vad.processAmplitude(-20, t(500)), isNull); // frame 1/3
      expect(vad.processAmplitude(-20, t(530)), isNull); // frame 2/3
      expect(vad.processAmplitude(-20, t(560)), VadEvent.speechStarted); // frame 3/3 -> xac nhan
      expect(vad.state, VadState.speaking);
      // Tiep tuc noi -> KHONG phat lai speechStarted.
      expect(vad.processAmplitude(-20, t(590)), isNull);
    });

    test('Chuoi lien tiep BI NGAT GIUA CHUNG (frame thu 2 tut xuong im lang) -> dem lai tu dau', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      expect(vad.processAmplitude(-20, t(500)), isNull); // frame 1/3
      expect(vad.processAmplitude(-55, t(530)), isNull); // NGAT — ve im lang, dem reset
      expect(vad.processAmplitude(-20, t(560)), isNull); // frame 1/3 (dem lai)
      expect(vad.processAmplitude(-20, t(590)), isNull); // frame 2/3
      expect(vad.processAmplitude(-20, t(620)), VadEvent.speechStarted); // frame 3/3
    });
  });

  group('VoiceActivityDetector — A2 Speech frame ratio', () {
    test('Frame ratio THAP (lich su gan day chu yeu im lang) CHAN xac nhan du dat consecutive-frame', () {
      // frameRatioWindow=6, minSpeechFrameRatio=0.5 (mac dinh). Neu 5
      // frame gan nhat la im lang roi moi co 3 frame lien tiep vuot
      // nguong, window 6 frame gan nhat se la [im,im,loud,loud,loud] chi
      // 5 phan tu (chua du 6) hoac tuong tu — dung 1 kich ban RO RANG:
      // 4 frame im lang lien tiep (khong lien quan consecutive-count vi
      // KHONG vuot nguong) roi 3 frame vuot nguong lien tiep -> window 6
      // gan nhat = [im,im,im,loud,loud,loud] (bo qua 1 im lang dau) ->
      // ratio = 3/6 = 0.5 -> VAN DU (bang nguong, khong nho hon) -> PHAI
      // xac nhan duoc. Test nay xac nhan hanh vi BIEN (>=), tach voi test
      // duoi day xac nhan truong hop RO RANG duoi nguong.
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      // 4 frame im lang (khong vuot nguong) NGAY SAU calibration.
      vad.processAmplitude(-55, t(500));
      vad.processAmplitude(-55, t(530));
      vad.processAmplitude(-55, t(560));
      vad.processAmplitude(-55, t(590));
      // 3 frame vuot nguong lien tiep.
      expect(vad.processAmplitude(-20, t(620)), isNull);
      expect(vad.processAmplitude(-20, t(650)), isNull);
      // Frame nay: consecutive du 3, window 6 gan nhat = [im,im,im,loud,loud,loud] (4 frame im lang truoc do, chi 3 con lai trong window 6).
      final event = vad.processAmplitude(-20, t(680));
      expect(event, VadEvent.speechStarted, reason: 'ratio dung bang nguong (3/6=0.5) van phai duoc chap nhan');
    });
  });

  group('VoiceActivityDetector — A4 Hysteresis (nguong bat dau khac nguong dung)', () {
    test('Dip am luong NHO giua cau (van tren stop threshold) KHONG bi coi la ket thuc noi', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      // Xac nhan speechStarted (start=-40, stop=-47).
      vad.processAmplitude(-20, t(500));
      vad.processAmplitude(-20, t(530));
      expect(vad.processAmplitude(-20, t(560)), VadEvent.speechStarted);

      // Dip xuong -45dB — DUOI start threshold (-40) nhung VAN TREN stop
      // threshold (-47) — PHAI duoc coi la VAN DANG NOI (khong bat dau
      // dem im lang), khac han truoc day (1 nguong duy nhat se coi day
      // la im lang ngay).
      expect(vad.processAmplitude(-45, t(600)), isNull);
      expect(vad.state, VadState.speaking, reason: 'Dip nho giua stop/start threshold KHONG duoc chuyen sang trailingSilence');
    });

    test('Am luong xuong DUOI stop threshold that su -> bat dau dem im lang, du 1500ms -> speechEnded', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      vad.processAmplitude(-20, t(500));
      vad.processAmplitude(-20, t(530));
      expect(vad.processAmplitude(-20, t(560)), VadEvent.speechStarted);

      // -50dB < stop threshold (-47) -> im lang THAT SU.
      expect(vad.processAmplitude(-50, t(600)), isNull);
      expect(vad.state, VadState.trailingSilence);
      expect(vad.processAmplitude(-50, t(600 + 1499)), isNull); // chua du 1500ms
      expect(vad.processAmplitude(-50, t(600 + 1500)), VadEvent.speechEnded);
      expect(vad.state, VadState.idle);
    });

    test('Noi lai (vuot start threshold) TRUOC KHI het nguong im lang -> huy dem, KHONG phat lai speechStarted', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      vad.processAmplitude(-20, t(500));
      vad.processAmplitude(-20, t(530));
      expect(vad.processAmplitude(-20, t(560)), VadEvent.speechStarted);
      expect(vad.processAmplitude(-50, t(600)), isNull); // bat dau im lang that su
      // Noi lai truoc khi het 1500ms.
      expect(vad.processAmplitude(-20, t(900)), isNull);
      expect(vad.state, VadState.speaking);
    });
  });

  group('VoiceActivityDetector — nhieu luot noi + reset/start', () {
    test('Nhieu luot noi lien tiep trong CUNG 1 phien (khong goi lai start giua 2 luot) van nhan dien dung', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      // Luot 1.
      vad.processAmplitude(-20, t(500));
      vad.processAmplitude(-20, t(530));
      expect(vad.processAmplitude(-20, t(560)), VadEvent.speechStarted);
      vad.processAmplitude(-50, t(600));
      expect(vad.processAmplitude(-50, t(2100)), VadEvent.speechEnded); // 1500ms tu 600

      // Luot 2 — can lai 3 frame lien tiep vuot nguong (dung nguong da
      // calibrate tu dau phien, KHONG can calibrate lai).
      vad.processAmplitude(-20, t(3000));
      vad.processAmplitude(-20, t(3030));
      expect(vad.processAmplitude(-20, t(3060)), VadEvent.speechStarted);
    });

    test('reset() dua ve trang thai chua khoi tao — xoa ca noise floor, processAmplitude sau reset() khong lam gi', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      vad.processAmplitude(-20, t(500));
      vad.reset();
      expect(vad.state, VadState.idle);
      expect(vad.noiseFloorDb, isNull);
      expect(vad.processAmplitude(-20, t(1000)), isNull); // chua goi lai start()
    });

    test('start() goi lai giua chung 1 luot noi -> reset sach, TINH LAI noise floor tu dau', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms));
      }
      vad.processAmplitude(-20, t(500)); // dang o giua chuoi consecutive
      vad.start(t(5000)); // reset thu cong (vd dong roi mo lai mic)
      expect(vad.state, VadState.idle);
      expect(vad.noiseFloorDb, isNull);
      // Calibration window moi tu t(5000).
      for (final ms in [5050, 5150, 5250, 5350, 5450]) {
        vad.processAmplitude(-60, t(ms));
      }
      vad.processAmplitude(-60, t(5500));
      expect(vad.noiseFloorDb, -60.0);
    });
  });

  group('VoiceActivityDetector — fixedSpeechThresholdDb (escape hatch)', () {
    test('Khi dat fixedSpeechThresholdDb -> BO QUA calibration, dung dung 1 nguong co dinh (van co hysteresis)', () {
      final vad = VoiceActivityDetector(fixedSpeechThresholdDb: -20.0, initialGracePeriod: Duration.zero);
      vad.start(t(0));
      // Khong can calibration window — co the danh gia speech NGAY.
      expect(vad.currentStartThresholdDb, -20.0);
      expect(vad.currentStopThresholdDb, -27.0); // -20 - (15-8)
      expect(vad.noiseFloorDb, isNull, reason: 'Che do fixed KHONG tinh noise floor');

      expect(vad.processAmplitude(-25, t(10)), isNull); // duoi nguong co dinh
      expect(vad.processAmplitude(-15, t(40)), isNull); // frame 1/3
      expect(vad.processAmplitude(-15, t(70)), isNull); // frame 2/3
      expect(vad.processAmplitude(-15, t(100)), VadEvent.speechStarted); // frame 3/3
    });
  });

  group('VoiceActivityDetector — kich ban thuc te tong hop', () {
    test('Mo phong 1 luot noi that: calibrate -> 3 frame xac nhan -> 1 dip tu nhien khong cat -> im lang that -> speechEnded', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      final events = <VadEvent>[];
      void feed(double db, int ms) {
        final e = vad.processAmplitude(db, t(ms));
        if (e != null) events.add(e);
      }

      // Calibration (noise floor ~ -55).
      feed(-55, 50);
      feed(-56, 150);
      feed(-54, 250);
      feed(-55, 350);
      feed(-55, 450);
      // 3 frame xac nhan bat dau noi.
      feed(-18, 500);
      feed(-16, 530);
      feed(-15, 560); // -> speechStarted
      // Noi tiep, co 1 dip nho tu nhien (-44, giua stop(-47) va start(-40)).
      feed(-14, 590);
      feed(-44, 620);
      feed(-16, 650);
      // Ket thuc noi that su.
      feed(-55, 680); // bat dau dem im lang tu day
      feed(-55, 680 + 1500); // -> speechEnded

      expect(events, [VadEvent.speechStarted, VadEvent.speechEnded]);
    });

    test('Am thanh nen/tieng on KHONG PHAI speech (duoi start threshold suot) -> KHONG BAO GIO phat speechStarted', () {
      final vad = VoiceActivityDetector();
      vad.start(t(0));
      for (final ms in [50, 150, 250, 350, 450]) {
        vad.processAmplitude(-55, t(ms)); // calibration
      }
      // Tieng quat/dieu hoa nen lien tuc, hoi cao hon noise floor calibrate
      // nhung KHONG vuot start threshold (-40).
      for (var i = 0; i < 50; i++) {
        expect(vad.processAmplitude(-42, t(500 + i * 30)), isNull);
      }
      expect(vad.state, VadState.idle);
    });
  });
}
