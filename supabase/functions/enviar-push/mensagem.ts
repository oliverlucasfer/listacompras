export type Tipo = "convite" | "membro";

export function tipoDoEvento(evento: string): Tipo | null {
  if (evento === "convite_email_criado") return "convite";
  if (evento === "membro_entrou") return "membro";
  return null;
}

export function montarMensagem(
  evento: string,
  tituloLista: string,
): { titulo: string; corpo: string } | null {
  const tipo = tipoDoEvento(evento);
  if (tipo === "convite") {
    return {
      titulo: "Convite para lista",
      corpo: `Você recebeu um convite para "${tituloLista}".`,
    };
  }
  if (tipo === "membro") {
    return {
      titulo: "Novo membro",
      corpo: `Um novo membro entrou em "${tituloLista}".`,
    };
  }
  return null;
}
