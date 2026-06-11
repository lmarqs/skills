# Worked example — retrospective technical documentation

A condensed, real technical doc written *after* an implementation (social login via Google + AWS
Cognito). Use it as a model for the retrospective shape: it documents what was built and why, the
flows in detail, and — distinctively — the **lessons learned** and a **version history**. Links and
images from the original are elided. (The skill writes in the language of the request — this example
is in English, but the same structure applies in any language.)

---

# Social Authentication with Google (AWS Cognito)

## Introduction

This document details the implementation of social login in the Admin system, using Google as the
identity provider and AWS Cognito as the authorization server (OAuth 2.0 / OIDC; in production,
Google→Cognito over SAML 2.0).

## Context

### Prior situation

Admin had only internal CPF-and-password authentication, with vulnerabilities: credential sharing,
weak passwords, an **access token with a long lifetime (12h)**, and **non-expiring refresh tokens
stored in localStorage** (XSS risk).

### Motivations for the change

- Simplify password management (don't store passwords internally).
- Reduce onboarding friction for staff.
- Security and compliance: leverage the Cognito/Google infrastructure (MFA, password rotation).

### Scope

Focused on the Admin system and staff authentication, designed to be reusable across other internal
systems. It does **not** manage authentication for users external to the company (clients, partners).

> The triad prior situation → motivations → scope is the retrospective equivalent of an RFC's
> "context": where we came from, why we changed, and how far the change reaches.

## Architecture

### Components involved

List each component with its responsibility, grouped by layer:

- **Frontend — admin-web-app:** starts the flow, receives the *code*, stores the tokens.
- **Backend — rest-api:** validates the access token against Cognito; keeps the CPF/password method.
- **AWS Lambda — collaborator-auth-cognito:** acquires, refreshes, and revokes tokens.
- **AWS Lambda — …-pre-token-gen:** enriches the access token with the user's email.
- **API Gateway — auth.example.com:** forwards token management / acts as a proxy.
- **AWS Cognito — user pool + client + IDP (Google).**

### Authentication flow

Document the flow as a **numbered, step-by-step** sequence (it accompanies the dynamic diagram):

1. **Flow start** — user clicks to sign in, triggering social login.
2. **Redirect with code** — Google/Cognito authenticates and redirects with an authorization code.
3. **Token request via POST** — the frontend sends the code to `/collaborator/exchange`.
4. **Lambda execution via API Gateway** — `APIGatewayProxyEventV2` event.
5. **Token request to Cognito** — exchanges code for tokens.
6. **Pre-Generate-Token Lambda** — trigger before the final issuance.
7. **access_token enrichment** — adds the email as a claim.
8. **Tokens returned** — access, id, and refresh.
9. **Response to frontend** — body `{ accessToken }`, `Set-Cookie: refreshToken` (HttpOnly).
10. **Client storage** — accessToken in localStorage, refreshToken in a Cookie.

#### Security pattern summary

| Token | Storage | Reason |
| --- | --- | --- |
| accessToken | localStorage | Fast access for API calls (short life, 15 min) |
| refreshToken | Cookie (HttpOnly) | Stronger protection against XSS (long life, 12h) |

> Also document the rest of the lifecycle flows: token **validation** (expiration/issuer → JWKs → user
> identification), **refresh**, and **revocation** (logout) — each as its own numbered sequence.

## Risk and mitigations

For intermittent failures of social authentication (Google/Cognito unavailability), a **feature flag in
Flipt** lets you switch between social and CPF/password (or keep both). [Step by step on operating the
flag.]

## Lessons learned

> The section that sets a retrospective document apart: what we discovered *by doing it*, so whoever
> comes next doesn't trip on the same stone.

- **Browser cookie management** — `SameSite`, `HttpOnly`, `Secure` are fundamental against XSS/CSRF;
  understanding each property was crucial.
- **Cognito User Pool schema is immutable** — changing the schema requires recreating the user pool; in
  production that would mean migrating all users.
- **CORS definitions** — should have been decided *before* implementation; adjusting them mid-work cost
  time and shifted directions (it motivated the API Gateway).
- **Short-lived tokens** — the architecture was conceived around short-lived tokens; studying the
  approach deeply (market recommendations, security impact) was essential.

## Improvement point

To raise security, improve the PKCE flow (validate `code_challenge`/`code_verifier`). Not implemented
today because initialization happens via Google Workspace with a fixed ACS URL, which prevents dynamic
generation of those parameters.

## Version history

| Version | Date | Author | Description |
| --- | --- | --- | --- |
| 1.0 | 2026-03-16 | Author A | Document created. |
| 1.1 | 2026-03-17 | Author B | Updated the logout flow. |
