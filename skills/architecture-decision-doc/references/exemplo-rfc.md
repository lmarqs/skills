# Worked example — forward-looking RFC

A condensed, real RFC (deciding the architecture of a new search service). Use it as a model for
*structure, depth, and tone* — especially the tradeoff table. Links and images from the original are
elided; in a real doc, keep them.

---

# RFC — Busca

**Status:** Em desenvolvimento

## Documentos relacionados

> Liste aqui os diagramas, planilhas e specs que a RFC referencia ao longo do texto (diagrama da
> solução, panorama dos endpoints atuais, design da nova API, mapeamento dos novos endpoints).

## Contextualização

O objetivo da Fase III é implementar o fluxo completo de compra (busca, carrinho, checkout). Este
documento descreve o que muda no sistema para atingir esse objetivo.

### O que não será abordado

- **Fluxo de checkout e compra** — será tratado em documento próprio, embora balize os requisitos da
  busca.
- **Mudanças no ranqueamento** — as regras de negócio do ranqueamento devem permanecer exatamente como
  hoje.

### Contextualização técnica

Hoje há duas fontes de dados para a busca: o banco transacional e o Elasticsearch, consultadas via
Public Search API e/ou Rest API. [Descreve cada índice, como é consultado, os cronjobs de
atualização, e percorre passo a passo o fluxo atual — modal de busca, resultado, slots — com os
endpoints envolvidos e suas dores conhecidas.]

> Note como esta seção assume *zero* conhecimento prévio: nomeia cada índice, cada endpoint, cada
> parâmetro. O óbvio é dito.

## Requisitos

> Antes dos requisitos, ancora onde se quer chegar (link para o Figma da nova experiência) e lista as
> dores atuais (queries que degradam o banco, custo do Elasticsearch, impossibilidade de filtrar por
> localização, falta de testes E2E). Só então enumera os requisitos — e deixa claro o foco: backend.

### Funcionais

- A busca não deve trazer quebras na experiência já existente (ordenações e filtros mantidos).
- A busca de procedimentos compara o termo com nome, palavras-chave e código TUSS.
- O usuário deve visualizar resultados condizentes apenas com a localização informada.
- Os resultados devem ser ranqueados de forma estritamente igual à de hoje.
- O sistema deve sanitizar os termos inseridos para evitar injeção de comandos.
- … (cada requisito concreto e verificável)

### Não funcionais

- Endpoints padronizados (nome do recurso, paginação, parâmetros, respostas) e erros consistentes.
- Observabilidade: logs estruturados com correlation ID, OpenTelemetry com tracing de requests e
  banco, dashboards de latência/erro.
- **Busca de agendas com response time ≤ 3.000ms no p95, validado em teste de carga.**
- Cobertura de testes automatizados > 90%, incluindo fluxo que valida o ranqueamento.
- (*Nice to have*) Diretório de ADRs versionando as decisões arquiteturais.

## Design

> Abre dimensionando a carga (≈360 requisições simultâneas no pico hipotético) para embasar as
> escolhas seguintes. Depois decide dimensão por dimensão, sempre amarrando aos requisitos:

### Provisionamento da aplicação

Lambda vs. cluster Kubernetes. A busca tem tráfego baixo à noite — padrão que favorece Lambda
(cobra por invocação + duração, sem pods ociosos). Combinada com Go, otimiza custo. Ponto de atenção:
conexões com o banco — até 360 simultâneas sem pool; já usamos RDS Proxy, que atenderia.

### Linguagem

JavaScript vs. Go, considerando o pico de 360 req simultâneas. Ambas lidam bem com I/O; Go sai na
frente em processamento de CPU (já tivemos problemas de CPU que motivaram a troca para Go no passado)
e, com Lambda, reduz consumo de recursos e custo.

### Bases de dados

Elasticsearch entrega ranqueamento e indexação prontos, mas tem custo alto e parte das buscas já não
o usa. Alternativa: usar o próprio Postgres (FTS: tsvector/tsquery, pg_trgm, ts_rank_cd). É sensível
pelo volume de operações — por isso uma **POC de Text Search do Postgres** embasa a decisão.

### Cache, consumo da API, diagramas, design da API

> Cada sub-tópico fecha amarrando ao requisito que resolve. Os diagramas (estático + dinâmico) e o
> design dos endpoints entram aqui, garantindo que **todo requisito está coberto** por algum endpoint.

## Análise das alternativas ou Análise de Tradeoff

> O coração do documento. Cada alternativa é analisada por **Positivo / Negativo / Risco**, e cada
> risco tem **Impacto, Probabilidade, Mitigação e Contingência**. Agrupe por dimensão decidida.

| Alternativa | Positivo | Negativo | Risco (descrição) | Impacto | Probabilidade | Mitigação | Contingência |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **[Base de dados] Banco como fonte única** | Elimina custo do Elasticsearch; fonte única, sem sincronização; FTS nativo do Postgres cobre os requisitos | Alta complexidade para replicar o ES (dis_max, boost, BM25); risco de impacto no banco transacional | Queries de busca textual competem com operações transacionais críticas | Alto | Média | Direcionar leitura de busca para read replica dedicada; índices GIN; VACUUM ANALYZE em baixo tráfego | Provisionar instância Postgres separada só para leitura da busca |
| | | Qualidade da busca inferior ao ES | Ranqueamento do ES é difícil de reproduzir no Postgres | Médio | Média | Validação comparativa Postgres vs. ES nos termos mais buscados antes de produção | — |
| **[Base de dados] ES aprimorado + banco p/ casos específicos** | Mantém maturidade da busca; separa responsabilidades; menor esforço | Mantém custo do ES; duas fontes com sincronização; reindexação | Processo sensível de reindexação | Médio | Alta | Blue-green indexing com versionamento de índices, sem downtime | Rollback do alias para o índice anterior |
| **[Provisionamento] AWS Lambda** | Custo otimizado para o padrão de uso; escala automática; menos overhead operacional | Cold start perceptível em busca interativa | Cold start adiciona centenas de ms | Baixo | Média | Provisioned Concurrency nos horários de menor uso | — |
| | | | Saturar o RDS Proxy | Alto | Média | Validar limites do RDS Proxy; monitorar conexões | Reserved Concurrency; aumentar instância do RDS Proxy |
| **[Linguagem] Golang** | Melhor em CPU; menor consumo (reduz custo de Lambda/pods); binário único; goroutines | Menor familiaridade do time; curva de aprendizado; dev mais lento no início | Curva de aprendizado gera menos produtividade no começo | Médio | Alta | Definir padrões Go antes de começar; estimar a curva no board; usar IA (Agents/Skills) | — |

> Repare: linhas adicionais sem repetir a alternativa acomodam **múltiplos riscos** por opção. Toda
> alternativa é batida contra os requisitos da seção 2.

## Processo de decisão em si

A partir das discussões, decidimos: **provisionamento em Lambda, linguagem Go, eliminando o
Elasticsearch e usando uma read replica dedicada do Core DB com FTS do Postgres como mecanismo de
busca.** [Diagrama da solução escolhida.]

> Decisão explícita e justificada. Não fica no "depende".

## Estratégia de lançamento

> Faseamento da entrega: lista os endpoints principais do fluxo de busca a migrar, depois os
> secundários, deixando claro o que fica fora por ora — para não ter "migração eterna".

## Tasks e roadmap

| Task | Descrição | Estimativa |
| --- | --- | --- |
| Setup inicial do projeto | README, estrutura de pastas (arquitetura hexagonal) | 2d |
| Migrations p/ tsvector + índices; pg_trgm; thresholds | management.procedure, partner.partner, … (usar CONCURRENTLY) | 5d |
| [Lambda search] /search/find-all-by-term | Busca unificada + testes + k6 | 3d |
| … | … | … |

> Quebra o trabalho em tarefas estimáveis; não precisa espelhar 1:1 o board, mas dá a forma do
> roadmap.
