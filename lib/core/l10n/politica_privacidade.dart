/// Canal de contato/encarregado (doc 06 §3.3.2). Preenchido pelo dono com o
/// e-mail da conta de desenvolvedor no momento do PR de publicação.
const contatoPrivacidadeEmail = 'oliverlucasfer@gmail.com';

/// Política de Privacidade do app local "Minhas Listas" (doc 06 §3.3): texto
/// único e simples, exibido in-app no onboarding e em Configurações (F21-T04).
/// Sem versão online desde 18/09/2026 (ADR-013 — a página estática do Hosting
/// foi removida junto com os artefatos de publicação).
const politicaPrivacidadeTextoLite =
    '''
Política de Privacidade — Minhas Listas

1. Dados que coletamos
O aplicativo funciona inteiramente no seu aparelho.
• Suas listas e itens ficam armazenados apenas no seu dispositivo.
• Não criamos conta, não pedimos e-mail nem senha e não enviamos seus dados para servidores nossos.

2. Voz
• O recurso de adicionar itens por voz usa o reconhecedor de fala do seu aparelho. Conforme o sistema, o áudio pode ser processado pelo serviço de reconhecimento do dispositivo (que pode usar a internet). Não gravamos nem guardamos o áudio.

3. Backup
• Você pode exportar um arquivo de backup e reimportá-lo. O arquivo é criado no seu aparelho e só sai dele por uma ação sua (compartilhar/salvar).

4. Com quem compartilhamos
Não compartilhamos dados com terceiros. Não há publicidade nem rastreamento.

5. Por quanto tempo guardamos
Seus dados ficam no aparelho até você excluí-los no próprio aplicativo (removendo listas ou o app).

6. Seus direitos
Você acessa, corrige e apaga tudo diretamente no aplicativo. O app não é direcionado a menores de 16 anos.

7. Contato
Dúvidas sobre privacidade: $contatoPrivacidadeEmail.
''';
