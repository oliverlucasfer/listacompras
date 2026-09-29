import '../config/app_modo.dart';

/// Sentry só liga no modo colaborativo **e** com DSN definido (F47/RF-32).
/// No Lite (100% local) nenhum dado de erro sai do aparelho, ainda que o
/// build traga um `SENTRY_DSN`.
bool sentryDeveIniciar(AppCapacidades cap, String dsn) =>
    cap.nuvem && dsn.trim().isNotEmpty;
