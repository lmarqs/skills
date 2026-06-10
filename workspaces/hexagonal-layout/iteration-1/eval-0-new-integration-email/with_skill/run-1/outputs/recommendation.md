# Where the welcome-email code goes

Short version: split it the same way the repo already splits storage. The
*decision* to send a welcome email is business logic and belongs in `app/`. The
*SendGrid call* is a connection to an external system and belongs in `infra/`.
The *choice to use SendGrid and the wiring* belongs in `run/`. The good news is
your repo already has a perfect template for this — `UserRepository` — so we
just follow the same seam.

## How the repo is laid out today

Your three top-level buckets map cleanly onto the three kinds of code:

- `app/` — **the reason.** Business logic and the interfaces it needs.
  `app/users/signup.py` is the `SignUp` use-case; `app/users/repository.py`
  declares the `UserRepository` Protocol — the interface the use-case needs from
  the outside world; `app/users/models.py` holds the `User` type. `app/` imports
  nothing from `infra/` or `run/`.
- `infra/` — **the connections.** `infra/postgres/user_repo.py` implements
  `UserRepository` against a real Postgres database. It depends *inward* on
  `app` (`from app.users.models import User`), never the other way around.
- `run/` — **how it's run.** `run/main.py`'s `build_signup()` picks the concrete
  `PostgresUserRepository`, opens the connection from `DATABASE_URL`, and hands
  it to `SignUp`. It depends on both `app` and `infra`.

Dependencies point toward the reason: `run → app ← infra`. That is the shape we
want to preserve. Sending email is structurally identical to saving a user —
both are the use-case reaching out to an external system through an interface it
owns — so it gets the same treatment.

## Placement, piece by piece

### 1. Declare the interface in the reason — `app/users/notifications.py` (new)

The `SignUp` use-case needs something that can send a welcome email, but it must
not know it's SendGrid. So `app/` declares the port it needs, exactly like
`repository.py` does for storage:

```python
# app/users/notifications.py
from typing import Protocol
from .models import User


class WelcomeNotifier(Protocol):
    """What the signup use-case needs to greet a new user. Implemented outside app/."""

    def send_welcome(self, user: User) -> None: ...
```

Why here: this is a build-time interface the reason owns, declared where it's
needed — the mirror image of `UserRepository`. No SendGrid types, no API keys,
no `import sendgrid` anywhere in `app/`. Keeping it a Protocol means the
use-case stays testable with a stand-in and stays independent of the email
vendor.

A note on naming: I'd call it `WelcomeNotifier` (or `Notifier`) rather than
`EmailSender`. The reason cares that the user gets *welcomed*, not that it
happens over email — that keeps the door open for SMS/push later without
touching `app/`. Match whatever phrasing reads best to you, but keep it about
intent.

### 2. Use the interface in the use-case — `app/users/signup.py` (edit)

`SignUp` takes the new port as a second constructor dependency and calls it
after the user is persisted:

```python
class SignUp:
    def __init__(self, users: UserRepository, notifier: WelcomeNotifier) -> None:
        self._users = users
        self._notifier = notifier

    def __call__(self, email: str, name: str) -> User:
        if self._users.exists(email):
            raise EmailAlreadyTaken(email)
        user = User(email=email, name=name)
        self._users.save(user)
        self._notifier.send_welcome(user)
        return user
```

Why here: "a new signup should be welcomed" is a business rule — *when* it
happens and *in what order* (after the save succeeds, not before) is the
use-case's decision, so it lives in the reason. The use-case is *handed* the
notifier; it never constructs one. (You may later want to decide whether a
failed email should roll back the signup or be best-effort — that's also a
business call that belongs right here, not in the SendGrid code.)

### 3. Implement the connection — `infra/sendgrid/welcome_notifier.py` (new)

This is where the actual SendGrid I/O lives — and the only place that imports
the SendGrid SDK. It implements the `app` interface, depending inward on `app`
just like `PostgresUserRepository` does:

```python
# infra/sendgrid/welcome_notifier.py
from app.users.models import User


class SendGridWelcomeNotifier:
    """Implements app.users.notifications.WelcomeNotifier via SendGrid."""

    def __init__(self, client, from_email: str) -> None:
        self._client = client
        self._from = from_email

    def send_welcome(self, user: User) -> None:
        # build the SendGrid payload and call the API here
        ...
```

Why here: this is a connection — reaching an external system to fulfil an
interface the reason declared. Mirror the existing `infra/postgres/` package
with a sibling `infra/sendgrid/` package. Keep it a *thin translation*: turn a
`User` into a SendGrid request and send it. Don't put "should we send?" or
"only for non-admins" logic here — any such rule is a business decision and
belongs back in `SignUp`, or a second notifier couldn't reuse it.

### 4. Wire it in — `run/main.py` (edit)

`run/` is where the connection and the reason meet. `build_signup()` picks the
concrete `SendGridWelcomeNotifier`, reads its config from the environment (just
as it already reads `DATABASE_URL`), and injects it into `SignUp`:

```python
def build_signup() -> SignUp:
    conn = psycopg.connect(os.environ["DATABASE_URL"])
    users = PostgresUserRepository(conn)

    client = make_sendgrid_client(os.environ["SENDGRID_API_KEY"])
    notifier = SendGridWelcomeNotifier(client, from_email=os.environ["WELCOME_FROM_EMAIL"])

    return SignUp(users, notifier)
```

Why here: choosing SendGrid, reading the API key, and assembling the use-case
are all "how it's run." This keeps the API key and the vendor choice out of
`app/` and `infra/`'s collaborators list — `run/` is the single place that knows
the whole picture.

## Files at a glance

| File | Change | Kind |
|---|---|---|
| `app/users/notifications.py` | **new** — `WelcomeNotifier` Protocol | Reason (interface it needs) |
| `app/users/signup.py` | edit — take notifier, call `send_welcome` after save | Reason (the rule + ordering) |
| `infra/sendgrid/welcome_notifier.py` | **new** — `SendGridWelcomeNotifier` | Connection (SendGrid I/O) |
| `run/main.py` | edit — construct notifier, inject into `SignUp` | How it's run (wiring + config) |

The arrows stay pointing inward: `infra/sendgrid` depends on `app`, `run`
depends on both, and `app` depends on neither.

## What this buys you

- **Vendor-independent** — swap SendGrid for SES/Postmark by adding one file in
  `infra/` and changing one line in `run/`; `app/` never moves.
- **Testable** — unit-test `SignUp` with a fake `WelcomeNotifier` that records
  calls, asserting the email is sent only after a successful save and not on
  `EmailAlreadyTaken` — no network, no API key.
- **Reusable** — any future entrypoint (a web handler, a CLI, a worker) reuses
  the same `SignUp` with whatever notifier it wires in.

## Smells to avoid while you build this

- Don't `import sendgrid` (or read `SENDGRID_API_KEY`) anywhere under `app/` —
  that drags the vendor and config into the reason and breaks testability.
- Don't declare the `WelcomeNotifier` interface inside `infra/` — that inverts
  the arrow; the reason owns the interfaces it needs.
- Don't put the "send a welcome on signup" decision inside the SendGrid class —
  keep that in `SignUp` so the connection stays a thin translation.

## One decision to make (business, not placement)

Should a SendGrid failure fail the whole signup, or be best-effort? That choice
lives in `SignUp` (the reason) — e.g. catch and log, enqueue a retry, or let it
propagate. Decide it there; the SendGrid class just sends and raises on error.
