# OCR (RF-37, F54) — ML Kit Text Recognition.
#
# O plugin google_mlkit_text_recognition referencia os reconhecedores
# opcionais de outros scripts (chines, devanagari, japones, coreano) que NAO
# fazem parte do classpath: o app usa apenas o modelo latino. Com o R8 ligado
# por padrao no AGP 9, o build de release falha com "Missing class"; estas
# regras fazem o R8 ignorar as referencias ausentes (elas nunca sao
# instanciadas pelo app). Regras sugeridas pelo proprio AGP em
# build/app/outputs/mapping/release/missing_rules.txt.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
