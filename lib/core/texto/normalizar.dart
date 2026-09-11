/// minúsculas + sem acento (pt-BR) + espaços colapsados nas pontas.
String normalizarTexto(String texto) {
  const acentos = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final semAcento = texto
      .toLowerCase()
      .split('')
      .map((c) => acentos[c] ?? c)
      .join();
  return semAcento.trim().replaceAll(RegExp(r'\s+'), ' ');
}
