import 'package:flutter/material.dart';

/// Bang mau/spacing rieng cho feature Mock Exam — mirror dung _DS cua
/// learn_screen.dart (khong dung shared/theme/app_colors.dart vi Mock Exam
/// hien thi LONG trong tab "Thi thử" cua Learn Hub, can dong bo thi giac
/// voi cac tab con lai (indigo/xanh), khong phai theme do chu dao toan app).
class ExamDS {
  static const bg = Color(0xFFF0F4FF);
  static const white = Colors.white;
  static const textDark = Color(0xFF1A1D2E);
  static const textGrey = Color(0xFF8A8FA3);
  static const indigo = Color(0xFF5B5FEF);
  static const indigoDark = Color(0xFF3B3FA8);
  static const indigoLight = Color(0xFFE8EAFF);
  static const green = Color(0xFF00C853);
  static const greenLight = Color(0xFFE8F5E9);
  static const red = Color(0xFFFF3D57);
  static const redLight = Color(0xFFFFEBEE);
  static const yellow = Color(0xFFFFB300);
  static const yellowLight = Color(0xFFFFF8E1);
  static const radius = 20.0;
  static const radiusSm = 14.0;
}

String sectionLabel(String? code) {
  switch (code) {
    case 'reading':
      return '📖 Đọc hiểu';
    case 'listening':
      return '🎧 Nghe hiểu';
    case 'grammar':
      return '✍️ Ngữ pháp';
    default:
      return code ?? '';
  }
}

String languageDisplayName(String languageCode) {
  return languageCode == 'en' ? 'Tiếng Anh' : 'Tiếng Trung (TOCFL)';
}
