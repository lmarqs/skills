import psycopg
from app.users.models import User


class PostgresUserRepository:
    """Implements app.users.repository.UserRepository against Postgres."""

    def __init__(self, conn: psycopg.Connection) -> None:
        self._conn = conn

    def save(self, user: User) -> None:
        self._conn.execute(
            "INSERT INTO users (email, name) VALUES (%s, %s)",
            (user.email, user.name),
        )

    def exists(self, email: str) -> bool:
        row = self._conn.execute(
            "SELECT 1 FROM users WHERE email = %s", (email,)
        ).fetchone()
        return row is not None
