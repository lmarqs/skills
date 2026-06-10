from .models import User
from .repository import UserRepository


class EmailAlreadyTaken(Exception):
    pass


class SignUp:
    """Use-case: register a new user."""

    def __init__(self, users: UserRepository) -> None:
        self._users = users

    def __call__(self, email: str, name: str) -> User:
        if self._users.exists(email):
            raise EmailAlreadyTaken(email)
        user = User(email=email, name=name)
        self._users.save(user)
        return user
