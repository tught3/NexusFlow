# google_mlkit_text_recognition: 한국어 인식기만 사용하므로 타 언어 인식기 클래스
# (중국어/데바나가리/일본어)는 로드되지 않음 — R8 경고 억제
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
