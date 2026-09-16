import 'normalizar.dart';

/// Busca local (RF-17): `true` quando [texto] contém [consulta], ignorando
/// caixa e acento (via [normalizarTexto]).
bool contemBusca(String texto, String consulta) =>
    normalizarTexto(texto).contains(normalizarTexto(consulta));
