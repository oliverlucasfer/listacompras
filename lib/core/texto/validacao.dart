/// Validação de e-mail compartilhada (F39): regex única usada em login,
/// registro, recuperação de senha e convite por e-mail (doc 05).
final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool emailValido(String valor) => _email.hasMatch(valor.trim());
