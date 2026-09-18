// realtime_test.mjs — F1-T07 (doc 01 §7, doc 02 §5 P-05)
// CP: eventos chegam a usuário MEMBRO e NÃO chegam a não-membro (2 contas).
//
// Uso: exporte as chaves do stack local (`supabase status -o env >> "$GITHUB_ENV"`)
//      e rode `npm test` — requer `supabase db reset` + `supabase start`.
// Variáveis: ANON_KEY e SERVICE_ROLE_KEY (esta só para criar as contas de teste
// já confirmadas; é a chave local do CLI, nunca a de um projeto real).

import { createClient } from '@supabase/supabase-js';

const URL =
  process.env.API_URL ?? process.env.SUPABASE_URL ?? 'http://127.0.0.1:54321';
const KEY =
  process.env.ANON_KEY ??
  process.env.SUPABASE_ANON_KEY ??
  'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH'; // publishable key local
const SERVICE =
  process.env.SERVICE_ROLE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function fail(msg) {
  console.error(`FALHOU: ${msg}`);
  process.exit(1);
}

if (!SERVICE) fail('defina SERVICE_ROLE_KEY (supabase status -o env)');

// --- 2 contas criadas pelo admin, já confirmadas ---
// O stack de teste não envia e-mail (config: enable_confirmations = true), então
// o signUp do cliente não serve aqui.
const emailA = `dono-${Date.now()}@test.local`;
const emailB = `outsider-${Date.now()}@test.local`;
const senha = 'senha-teste-123';

const admin = createClient(URL, SERVICE, { auth: { persistSession: false } });
const { data: criadaA, error: errCriadaA } = await admin.auth.admin.createUser({
  email: emailA,
  password: senha,
  email_confirm: true,
});
if (errCriadaA) fail(`criar conta A: ${errCriadaA.message}`);
const { data: criadaB, error: errCriadaB } = await admin.auth.admin.createUser({
  email: emailB,
  password: senha,
  email_confirm: true,
});
if (errCriadaB) fail(`criar conta B: ${errCriadaB.message}`);

const idA = criadaA.user.id;
const idB = criadaB.user.id;

// --- sessões (a Realtime precisa do JWT do usuário) ---
const clienteA = createClient(URL, KEY, { auth: { persistSession: false } });
const clienteB = createClient(URL, KEY, { auth: { persistSession: false } });

const { data: sessaoA, error: errSessaoA } =
  await clienteA.auth.signInWithPassword({ email: emailA, password: senha });
if (errSessaoA) fail(`login A: ${errSessaoA.message}`);
const { data: sessaoB, error: errSessaoB } =
  await clienteB.auth.signInWithPassword({ email: emailB, password: senha });
if (errSessaoB) fail(`login B: ${errSessaoB.message}`);

// --- A cria lista (o trigger criar_membro_dono insere a membresia — 0010) ---
const listaId = crypto.randomUUID();
const { error: errLista } = await clienteA.from('listas').insert({
  id: listaId,
  titulo: 'Realtime',
  dono_id: idA,
});
if (errLista) fail(`insert listas: ${errLista.message}`);

// --- ambos assinam postgres_changes em itens_lista (RLS filtra) ---
clienteA.realtime.setAuth(sessaoA.session.access_token);
clienteB.realtime.setAuth(sessaoB.session.access_token);
let recebeuA = null;
let recebeuB = null;

const chA = clienteA.channel('t-a').on(
  'postgres_changes',
  { event: 'INSERT', schema: 'public', table: 'itens_lista' },
  (payload) => {
    recebeuA = payload;
  },
);
const chB = clienteB.channel('t-b').on(
  'postgres_changes',
  { event: 'INSERT', schema: 'public', table: 'itens_lista' },
  (payload) => {
    recebeuB = payload;
  },
);

const subA = new Promise((res) =>
  chA.subscribe((s, errCtx) => {
    if (s !== 'SUBSCRIBED') console.log(`[diag A]`, s, errCtx ?? '');
    if (s === 'SUBSCRIBED') res(true);
  }),
);
const subB = new Promise((res) =>
  chB.subscribe((s, errCtx) => {
    if (s !== 'SUBSCRIBED') console.log(`[diag B]`, s, errCtx ?? '');
    if (s === 'SUBSCRIBED') res(true);
  }),
);
console.log('aguardando subscrição...');
const okA = await Promise.race([subA, sleep(35000).then(() => null)]);
const okB = await Promise.race([subB, sleep(35000).then(() => null)]);
if (!okA) fail('canal A não subscreveu');
if (!okB) fail('canal B não subscreveu');
console.log('OK setup: ambos os canais subscritos');

// --- A insere item ---
const itemId = crypto.randomUUID();
const { error: errItem } = await clienteA.from('itens_lista').insert({
  id: itemId,
  lista_id: listaId,
  nome: 'Café',
});
if (errItem) fail(`insert itens: ${errItem.message}`);

// --- espera evento ---
await sleep(5000);

// julgamento
const membroOk = recebeuA?.new?.id === itemId;
const outsiderOk = recebeuB === null;

clienteA.removeChannel(chA);
clienteB.removeChannel(chB);

if (!membroOk) fail('membro NÃO recebeu o evento');
if (!outsiderOk) fail('não-membro RECEBEU o evento (vazamento RLS!)');
console.log('OK P-05: membro recebeu evento < 5s; não-membro recebeu 0 eventos');
console.log('TODOS OS TESTES REALTIME PASSARAM');
process.exit(0);
