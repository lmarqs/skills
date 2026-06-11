# Worked example — retrospective technical documentation

A condensed, real technical doc written *after* an implementation (social login via Google + AWS
Cognito). Use it as a model for the retrospective shape: it documents what was built and why, the
flows in detail, and — distinctively — the **lessons learned** and a **version history**. Links and
images from the original are elided.

---

# Implementação de Autenticação Social com Google (AWS Cognito)

## Introdução

Este documento detalha a implementação da autenticação via login social no sistema Admin, usando o
Google como provedor de identidade e o AWS Cognito como servidor de autorização (OAuth 2.0 / OIDC;
em produção, Google→Cognito via SAML 2.0).

## Contexto

### Situação anterior

O Admin tinha apenas autenticação interna por CPF e senha, com vulnerabilidades: compartilhamento de
credenciais, senhas fracas, **access token com vida longa (12h)** e **refresh tokens eternos
guardados no localStorage** (risco de XSS).

### Motivações para a mudança

- Simplificar o gerenciamento de senhas (não armazenar senhas internamente).
- Reduzir fricção no onboarding de colaboradores.
- Segurança e conformidade: aproveitar a infraestrutura do Cognito/Google (MFA, rotação de senha).

### Escopo

Focou no sistema Admin e na autenticação de colaboradores, desenhada para ser reusável em outros
sistemas internos. **Não** gerencia autenticação de usuários externos (clientes, parceiros).

> A tríade situação anterior → motivações → escopo é o equivalente retrospectivo da "Contextualização"
> da RFC: de onde viemos, por que mudamos, e até onde a mudança vai.

## Arquitetura

### Componentes envolvidos

Liste cada componente com sua responsabilidade, agrupados por camada:

- **Frontend — medprev-admin-web-app:** inicia o fluxo, recebe o *code*, armazena os tokens.
- **Backend — medprev-rest-api:** valida o access token junto ao Cognito; mantém o método CPF/senha.
- **AWS Lambda — medprev-collaborator-auth-cognito:** adquire, atualiza e revoga tokens.
- **AWS Lambda — …-pre-token-gen:** enriquece o access token com o e-mail do usuário.
- **API Gateway — auth.medprev.online:** encaminha o gerenciamento de tokens / atua como proxy.
- **AWS Cognito — user pool + client + IDP (Google).**

### Fluxo de autenticação

Documente o fluxo como uma sequência **numerada e passo a passo** (acompanha o diagrama dinâmico):

1. **Início do fluxo** — usuário clica para entrar, dispara o login social.
2. **Redirecionamento com código** — Google/Cognito autentica e redireciona com um authorization code.
3. **Solicitação de tokens via POST** — o frontend envia o code para `/collaborator/exchange`.
4. **Execução da Lambda via API Gateway** — evento `APIGatewayProxyEventV2`.
5. **Solicitação de tokens ao Cognito** — troca code por tokens.
6. **Pre-Generate-Token Lambda** — trigger antes da emissão final.
7. **Enriquecimento do access_token** — adiciona o e-mail como claim.
8. **Retorno dos tokens** — access, id e refresh.
9. **Resposta ao frontend** — body `{ accessToken }`, `Set-Cookie: refreshToken` (HttpOnly).
10. **Armazenamento no cliente** — accessToken no localStorage, refreshToken no Cookie.

#### Resumo do padrão de segurança

| Token | Armazenamento | Motivo |
| --- | --- | --- |
| accessToken | localStorage | Acesso rápido às chamadas de API (vida curta, 15 min) |
| refreshToken | Cookie (HttpOnly) | Maior segurança contra XSS (vida longa, 12h) |

> Documente também os demais fluxos do ciclo de vida: **validação** do token (expiração/issuer → JWKs
> → identificação do usuário), **atualização** (refresh) e **revogação** (logout) — cada um como sua
> própria sequência numerada.

## Risco e mitigações

Para falhas intermitentes da autenticação social (indisponibilidade do Google/Cognito), uma
**feature-flag no Flipt** permite alternar entre social e CPF/senha (ou manter ambas). [Passo a passo
de como operar a flag.]

## Lições aprendidas

> Seção que diferencia o documento retrospectivo: o que descobrimos *fazendo*, para quem vier depois
> não tropeçar na mesma pedra.

- **Gerenciamento de Cookie pelo navegador** — `SameSite`, `HttpOnly`, `Secure` são fundamentais
  contra XSS/CSRF; entender cada propriedade foi crucial.
- **Schema do Cognito User Pool é imutável** — alterar o schema exige recriar o user pool; em
  produção, isso significaria migrar todos os usuários.
- **Definições de CORS** — deveriam ter sido decididas *antes* da implementação; ajustá-las durante o
  trabalho custou tempo e mudou direcionamentos (motivou o API Gateway).
- **Short-lived tokens** — a arquitetura foi concebida em torno de tokens de curta duração; estudar a
  abordagem a fundo (recomendações de mercado, impacto em segurança) foi essencial.

## Ponto de melhoria

Para aumentar a segurança, aprimorar o fluxo PKCE (validar `code_challenge`/`code_verifier`). Hoje não
implementado porque a inicialização ocorre via Google Workspace com ACS URL fixa, o que impede a
geração dinâmica desses parâmetros.

## Histórico de versões

| Versão | Data | Autor | Descrição |
| --- | --- | --- | --- |
| 1.0 | 16/03/2026 | Giovani Brollo Cunha | Criação do documento. |
| 1.1 | 17/03/2026 | Paulo Eduardo de Sordi Gomes | Alteração do fluxo de logout. |
