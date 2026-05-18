// OCR 서비스 - ML Kit 기반 on-device 텍스트 인식
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OcrService {
  static OcrService? _instance;
  static OcrService get instance => _instance ??= OcrService._();
  OcrService._();

  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.korean,
  );

  /// 이미지 파일에서 텍스트 추출
  Future<OcrResult> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFile(File(imagePath));
      final recognized = await _recognizer.processImage(inputImage);
      final text = recognized.text.trim();
      return OcrResult(
        text: text,
        success: text.isNotEmpty,
        imagePath: imagePath,
      );
    } catch (e) {
      return OcrResult(
        text: '',
        success: false,
        imagePath: imagePath,
        error: e.toString(),
      );
    }
  }

  /// 텍스트에서 관련성 판별 (Dictionary 키워드 + 거래처명 매칭)
  bool isRelevant({
    required String text,
    required List<String> keywords,
    required List<String> accountNames,
    required List<String> contactNames,
  }) {
    if (text.isEmpty) return false;
    final lowerText = text.toLowerCase();

    for (final keyword in keywords) {
      if (lowerText.contains(keyword.toLowerCase())) return true;
    }
    for (final name in accountNames) {
      if (name.length >= 2 && lowerText.contains(name.toLowerCase())) {
        return true;
      }
    }
    for (final name in contactNames) {
      if (name.length >= 2 && lowerText.contains(name.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  void dispose() {
    _recognizer.close();
  }
}

class OcrResult {
  const OcrResult({
    required this.text,
    required this.success,
    required this.imagePath,
    this.error,
  });

  final String text;
  final bool success;
  final String imagePath;
  final String? error;
}

final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService.instance;
});
