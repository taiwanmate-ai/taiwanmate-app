import 'package:flutter/material.dart';

/// Pinyin MAU THEO THANH (Q3 R3): thanh 1 đỏ, thanh 2 xanh lá, thanh 3 xanh dương, thanh 4 tím, thanh nhẹ xám. LOGIC THUẦN (test được) + widget.
const kToneColors = <int, Color>{
  1: Color(0xFFE53935),
  2: Color(0xFF2E7D32),
  3: Color(0xFF1E88E5),
  4: Color(0xFF8E24AA),
  0: Color(0xFF8A8FA3),
};

const _t1 = 'āēīōūǖ';
const _t2 = 'áéíóúǘ';
const _t3 = 'ǎěǐǒǔǚ';
const _t4 = 'àèìòùǜ';

/// Thanh của MỘT âm tiết pinyin (1–4, 0 = thanh nhẹ / không dấu).
int toneOfSyllable(String syllable) {
  for (final ch in syllable.runes.map(String.fromCharCode)) {
    if (_t1.contains(ch)) return 1;
    if (_t2.contains(ch)) return 2;
    if (_t3.contains(ch)) return 3;
    if (_t4.contains(ch)) return 4;
  }
  return 0;
}

/// Tách chuỗi pinyin thành các mảnh (âm tiết hoặc dấu câu/khoảng trắng) để tô màu từng âm tiết; mảnh không phải âm tiết có thanh = null.
List<(String, int?)> toneSegments(String pinyin) {
  final out = <(String, int?)>[];
  final re = RegExp(r"[A-Za-züÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ']+|[^A-Za-züÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ']+");
  for (final m in re.allMatches(pinyin)) {
    final t = m.group(0)!;
    final isWord = RegExp(r"^[A-Za-züÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ']+$").hasMatch(t);
    out.add((t, isWord ? toneOfSyllable(t) : null));
  }
  return out;
}

/// Hán Việt chỉ hiện khi ĐỦ âm cho MỌI chữ Hán của từ (số âm tiết == số chữ Hán). Thiếu/dư -> ẩn (server đã ẩn từ chưa đủ, đây là chốt chặn thứ hai).
String? displayHanViet(String hanzi, String? hanViet) {
  final hv = (hanViet ?? '').trim();
  if (hv.isEmpty) return null;
  final chars = RegExp(r'[㐀-鿿]').allMatches(hanzi).length;
  final syl = hv.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).length;
  if (chars == 0 || syl != chars) return null;
  return hv.toUpperCase();
}

class PinyinText extends StatelessWidget {
  final String pinyin;
  final double fontSize;
  final TextAlign align;
  const PinyinText(this.pinyin, {super.key, this.fontSize = 16, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        for (final (t, tone) in toneSegments(pinyin))
          TextSpan(text: t, style: TextStyle(color: tone == null ? const Color(0xFF8A8FA3) : kToneColors[tone], fontWeight: tone == null ? FontWeight.w400 : FontWeight.w600)),
      ]),
      textAlign: align,
      style: TextStyle(fontSize: fontSize),
    );
  }
}
