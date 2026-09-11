import 'package:flutter/material.dart';

/// Paleta base e cores semânticas (doc 15 §1).
abstract final class AppColors {
  static const seed = Color(0xFF2E7D32);

  // Semânticas — claro
  static const successClaro = Color(0xFF3B6939);
  static const onSuccessClaro = Color(0xFFFFFFFF);
  static const successContainerClaro = Color(0xFFBDF0B4);
  static const onSuccessContainerClaro = Color(0xFF00210B);

  static const warningClaro = Color(0xFF7A5900);
  static const onWarningClaro = Color(0xFFFFFFFF);
  static const warningContainerClaro = Color(0xFFFFDEA6);
  static const onWarningContainerClaro = Color(0xFF261A00);

  static const infoClaro = Color(0xFF00639B);
  static const onInfoClaro = Color(0xFFFFFFFF);
  static const infoContainerClaro = Color(0xFFCFE5FF);
  static const onInfoContainerClaro = Color(0xFF001D34);

  // Semânticas — escuro
  static const successEscuro = Color(0xFFA1D39A);
  static const onSuccessEscuro = Color(0xFF0B390C);
  static const successContainerEscuro = Color(0xFF235024);
  static const onSuccessContainerEscuro = Color(0xFFBDF0B4);

  static const warningEscuro = Color(0xFFF2C14E);
  static const onWarningEscuro = Color(0xFF3F2E00);
  static const warningContainerEscuro = Color(0xFF5C4300);
  static const onWarningContainerEscuro = Color(0xFFFFDEA6);

  static const infoEscuro = Color(0xFF95CCFF);
  static const onInfoEscuro = Color(0xFF003354);
  static const infoContainerEscuro = Color(0xFF004A77);
  static const onInfoContainerEscuro = Color(0xFFCFE5FF);
}
