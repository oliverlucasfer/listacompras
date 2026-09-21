/// O que aconteceu ao adicionar um item com dedup (RF-10/RF-23): insere um
/// novo, soma a quantidade de um existente (mesma unidade) ou substitui
/// quantidade/unidade (unidade diferente).
enum ResultadoDedup { adicionado, somado, substituido }
