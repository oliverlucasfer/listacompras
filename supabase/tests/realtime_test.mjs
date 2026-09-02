// realtime_test.mjs — F1-T07 (doc 01 §7, doc 02 §5 P-05)
// CP: eventos chegam a usuário MEMBRO e NÃO chegam a não-membro (2 contas).
//
// Uso: node realtime_test.mjs
// Requer `supabase db reset` + `supabase start` rodando.

import { createClient } from '@supabase/supabase-js';

const URL = 'http://127.0.0.1:54321';
const KEY = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH'; // publishable key local (pública por design)

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function fail(msg) {
  console.error(`FALHOU: ${msg}`);
  process.exit(1);
}

// --- 2 contas ---
const emailA = `dono-${Date.now()}@test.local`;
const emailB = `outsider-${Date.now()}@test.local`;
const senha = 'senha-teste-123';

const adminA = createClient(URL, KEY);
const adminB = createClient(URL, KEY);

const { data: authA, error: errA } = await adminA.auth.signUp({ email: emailA, password: senha });
if (errA) fail(`signup A: ${errA.message}`);
const { data: authB, error: errB } = await adminB.auth.signUp({ email: emailB, password: senha });
if (errB) fail(`signup B: ${errB.message}`);

const idA = authA.user.id;
const idB = authB.user.id;

// --- A cria lista + se insere como dono (policies 0002) ---
const listaId = crypto.randomUUID();
const { error: errLista } = await adminA.from('listas').insert({ id: listaId, titulo: 'Realtime', dono_id: idA });
if (errLista) fail(`insert listas: ${errLista.message}`);
const { error: errMembro } = await adminA.from('lista_membros').insert({ lista_id: listaId, user_id: idA, papel: 'dono' });
if (errMembro) fail(`insert lista_membros: ${errMembro.message}`);

// --- ambos assinam postgres_changes em itens_lista (RLS filtra) ---
// setAuth explícito: o supabase-js não propaga o token automaticamente
// quando o canal é criado logo após o signUp.
adminA.realtime.setAuth(authA.session.access_token);
adminB.realtime.setAuth(authB.session.access_token);
let recebeuA = null;
let recebeuB = null;

const chA = adminA.channel('t-a').on(
  'postgres_changes',
  { event: 'INSERT', schema: 'public', table: 'itens_lista' },
  (payload) => { recebeuA = payload; }
);
const chB = adminB.channel('t-b').on(
  'postgres_changes',
  { event: 'INSERT', schema: 'public', table: 'itens_lista' },
  (payload) => { recebeuB = payload; }
);

const subA = new Promise((res) => chA.subscribe((s, errCtx) => { if (s !== 'SUBSCRIBED') console.log(`[diag A]`, s, errCtx ?? ''); if (s === 'SUBSCRIBED') res(true); }));
const subB = new Promise((res) => chB.subscribe((s, errCtx) => { if (s !== 'SUBSCRIBED') console.log(`[diag B]`, s, errCtx ?? ''); if (s === 'SUBSCRIBED') res(true); }));
const tSub = Date.now();
console.log('aguardando subscrição...');
const okA = await Promise.race([subA, sleep(35000).then(() => null)]);
const okB = await Promise.race([subB, sleep(35000).then(() => null)]);
if (!okA) fail('canal A não subscreveu');
if (!okB) fail('canal B não subscreveu');
console.log('OK setup: ambos os canais subscritos');

// --- A insere item ---
const itemId = crypto.randomUUID();
const { error: errItem } = await adminA.from('itens_lista').insert({ id: itemId, lista_id: listaId, nome: 'Café' });
if (errItem) fail(`insert itens: ${errItem.message}`);

// --- espera evento ---
await sleep(5000);

// julgamento
const membroOk = recebeuA?.new?.id === itemId;
const outsiderOk = recebeuB === null;

adminA.removeChannel(chA);
adminB.removeChannel(chB);

if (!membroOk) fail('membro NÃO recebeu o evento');
if (!outsiderOk) fail('não-membro RECEBEU o evento (vazamento RLS!)');
console.log('OK P-05: membro recebeu evento < 5s; não-membro recebeu 0 eventos');
console.log('TODOS OS TESTES REALTIME PASSARAM');
process.exit(0);
