<!--
  Skeleton for a forward-looking architecture decision document (RFC / design doc).
  Translate the headings into the document's language (match the request and source material).
  Treat sections as a checklist, not a cage: drop what doesn't apply, add what the decision needs.
  Headings below are in Portuguese, mirroring the worked example; swap to English etc. as needed.
-->

# RFC — <título da decisão>

**Status:** <rascunho | em revisão | aprovado>

## Documentos relacionados

- <diagramas, planilhas, specs, dashboards que este documento referencia>

## Contextualização

<Escrito para quem está conhecendo o projeto agora. O que existe hoje, por que estamos olhando para
isso, sem ambiguidade — diga o óbvio.>

### O que não será abordado

- <não-objetivos: o que fica explicitamente fora de escopo, e por quê>

## Requisitos

<Apenas os arquiteturalmente relevantes: críticos para o negócio ou caros/irreversíveis de desfazer.>

### Funcionais

- <o que o sistema deve fazer — concreto e verificável>

### Não funcionais

- <quão bem: latência (ex.: p95 ≤ Xms validado em carga), observabilidade, cobertura de testes,
  segurança, padronização>

## Design

<Resolva os requisitos com tecnologia. Componentes e como cada requisito é atendido. Decida dimensão
por dimensão, sempre amarrando ao requisito que resolve.>

- **Diagrama estático:** <componentes e como se encaixam — ou link/placeholder>
- **Diagrama dinâmico:** <fluxo/sequência ao longo do tempo — ou link/placeholder>

## Análise das alternativas (Tradeoff)

<Para cada alternativa: Positivo, Negativo, Risco. Cada risco com Impacto, Probabilidade, Mitigação e
Contingência. Agrupe por dimensão decidida. Bata cada alternativa contra os requisitos.>

| Alternativa | Positivo | Negativo | Risco (descrição) | Impacto | Probabilidade | Mitigação | Contingência |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <opção A> | <prós> | <contras> | <risco> | baixo/médio/alto | baixa/média/alta | <evitar o risco> | <agir se ocorrer> |
| <opção B> | | | | | | | |

## Processo de decisão

<Qual alternativa foi escolhida e por quê. Estilo da decisão: autocrático (sua a decisão final) ou
democrático (maioria). Comprometa-se — não fique no "depende".>

## Estratégia de lançamento

<Como entregar em fases, sem migração eterna. O que entra agora, o que fica para depois.>

## Tasks e roadmap

| Task | Descrição | Estimativa |
| --- | --- | --- |
| <tarefa> | <descrição> | <Xd> |

## Histórico de versões

| Versão | Data | Autor | Descrição |
| --- | --- | --- | --- |
| 1.0 | <dd/mm/aaaa> | <autor> | Criação do documento. |
