import os
import psycopg
from app.users.signup import SignUp
from infra.postgres.user_repo import PostgresUserRepository


def build_signup() -> SignUp:
    conn = psycopg.connect(os.environ["DATABASE_URL"])
    users = PostgresUserRepository(conn)
    return SignUp(users)


if __name__ == "__main__":
    signup = build_signup()
    signup(email="ada@example.com", name="Ada")
