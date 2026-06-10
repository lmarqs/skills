# Where the welcome-email code goes

Short answer: define the email-sending as a **port (Protocol) in `app/`**, write the **SendGrid implementation as an adapter in `infra/`**, call the port **from the `SignUp` use-case**, and **wire the concrete adapter in `run/main.py`**. The `SignUp` use-case must never `import sendgrid` directly.

This follows the layout the repo already uses, which is ports-and-adapters (hexagonal):

- `app/` — domain entities, use-cases, and the *ports* (Protocols) they depend on. Pure Python, no third-party I/O libraries. Today: `app/users/models.py` (the `User` entity), `app/users/repository.py` (the `UserRepository` port), `app/users/signup.py` (the `SignUp` use-case).
- `infra/` — concrete *adapters* that implement those ports against real technology. Today: `infra/postgres/user_repo.py` (`PostgresUserRepository` implements `UserRepository`, and is the only file that imports `psycopg`).
- `run/` — the composition root that constructs adapters and injects them into use-cases. Today: `run/main.py`'s `build_signup()`.

Sending an email through SendGrid is the exact same shape of problem as "save a user to Postgres": the use-case needs an external capability, but it should depend on *what* it needs, not on *how* it's done. So we mirror the existing repository pattern.

## Piece by piece

### 1. The port — `app/users/notifications.py` (new file in `app/`)

Define a Protocol describing what the signup use-case needs, by analogy with `app/users/repository.py`. It belongs next to the other `app/users` abstractions because it is part of the use-case's required interface.

```python
# app/users/notifications.py
from typing import Protocol
from .models import User


class WelcomeMailer(Protocol):
    """What the signup use-case needs to greet a new user. Implemented outside app/."""

    def send_welcome(self, user: User) -> None: ...
```

Notes:
- The method takes the domain `User` (already defined in `app/users/models.py`), not raw strings — that keeps the use-case clean and lets the adapter decide which fields to use.
- The name describes the *intent* ("welcome mailer"), not the vendor. There is no mention of SendGrid here. That is deliberate: `app/` stays ignorant of the technology, exactly like `UserRepository` says nothing about Postgres.
- No new dependency is added to `app/` — `Protocol` is stdlib, same as `repository.py`.

### 2. The use-case — edit `app/users/signup.py`

`SignUp` already receives its `UserRepository` by constructor injection. Add the mailer the same way and call it after the user is persisted.

```python
# app/users/signup.py
from .models import User
from .repository import UserRepository
from .notifications import WelcomeMailer


class EmailAlreadyTaken(Exception):
    pass


class SignUp:
    """Use-case: register a new user."""

    def __init__(self, users: UserRepository, mailer: WelcomeMailer) -> None:
        self._users = users
        self._mailer = mailer

    def __call__(self, email: str, name: str) -> User:
        if self._users.exists(email):
            raise EmailAlreadyTaken(email)
        user = User(email=email, name=name)
        self._users.save(user)
        self._mailer.send_welcome(user)
        return user
```

Why here: "send a welcome email on signup" is a policy decision about *when* the email goes out, and that policy lives in the use-case. The use-case orchestrates; it depends only on the `WelcomeMailer` Protocol, so it stays unit-testable with a fake mailer and never imports SendGrid.

(Ordering note for later, not a placement question: sending after `save` means a SendGrid outage won't lose the registration. If you later want the email to never block signup, the use-case is also the right place to hand it to a background queue — still behind the same port.)

### 3. The adapter — `infra/sendgrid/welcome_mailer.py` (new file in `infra/`)

This is where SendGrid actually lives. It mirrors `infra/postgres/user_repo.py`: a new subpackage named after the technology (`infra/sendgrid/`, parallel to `infra/postgres/`), one class implementing the `app` port, and it is the *only* place that imports the vendor SDK.

```python
# infra/sendgrid/welcome_mailer.py
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
from app.users.models import User


class SendGridWelcomeMailer:
    """Implements app.users.notifications.WelcomeMailer using SendGrid."""

    def __init__(self, client: SendGridAPIClient, from_email: str) -> None:
        self._client = client
        self._from_email = from_email

    def send_welcome(self, user: User) -> None:
        message = Mail(
            from_email=self._from_email,
            to_emails=user.email,
            subject="Welcome!",
            html_content=f"<p>Hi {user.name}, welcome aboard.</p>",
        )
        self._client.send(message)
```

Notes:
- Like `PostgresUserRepository` takes a `psycopg.Connection` rather than reading `DATABASE_URL` itself, this adapter takes the already-built SendGrid client (and the from-address) via its constructor. Connection/credential setup is the composition root's job, not the adapter's.
- The exact SendGrid client/Mail call signatures shown above should be confirmed against the current SendGrid Python SDK before you implement — treat this snippet as the shape, not the final API.

### 4. The wiring — edit `run/main.py`

The composition root builds the SendGrid client from environment config and injects the adapter into `SignUp`, exactly as it already does for the Postgres repository.

```python
# run/main.py
import os
import psycopg
from sendgrid import SendGridAPIClient
from app.users.signup import SignUp
from infra.postgres.user_repo import PostgresUserRepository
from infra.sendgrid.welcome_mailer import SendGridWelcomeMailer


def build_signup() -> SignUp:
    conn = psycopg.connect(os.environ["DATABASE_URL"])
    users = PostgresUserRepository(conn)

    sg_client = SendGridAPIClient(os.environ["SENDGRID_API_KEY"])
    mailer = SendGridWelcomeMailer(sg_client, from_email=os.environ["WELCOME_FROM_EMAIL"])

    return SignUp(users, mailer)
```

Why here: `run/` is the only layer allowed to know about every concrete dependency at once — it reads env vars (`os.environ`, as it already does for `DATABASE_URL`) and assembles the graph. Adding the mailer here keeps `app/` and `infra/` unaware of each other's construction.

## Summary table

| New/changed piece | Location | Mirrors existing |
| --- | --- | --- |
| `WelcomeMailer` port (Protocol) | `app/users/notifications.py` (new) | `app/users/repository.py` |
| `SignUp` calls the mailer | `app/users/signup.py` (edit) | existing `self._users` usage |
| `SendGridWelcomeMailer` adapter | `infra/sendgrid/welcome_mailer.py` (new) | `infra/postgres/user_repo.py` |
| Build + inject the adapter | `run/main.py` (edit) | existing `build_signup()` |

## The one rule that drives all of this

Dependencies point inward: `run/` → `infra/` → `app/`, and `app/` depends on nobody. The SendGrid SDK import appears in exactly one new file (`infra/sendgrid/welcome_mailer.py`) plus the composition root (`run/main.py`). If you ever find yourself writing `import sendgrid` inside `app/`, the email code has landed in the wrong layer.

A quick test you can run after wiring: instantiate `SignUp` in a unit test with a fake repository and a fake mailer (both just plain classes implementing the two Protocols) and assert `send_welcome` was called — no SendGrid, no Postgres needed. If that test is easy to write, the placement is correct.
