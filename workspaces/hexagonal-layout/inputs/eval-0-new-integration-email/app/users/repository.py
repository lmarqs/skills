from typing import Protocol
from .models import User


class UserRepository(Protocol):
    """What the signup use-case needs from storage. Implemented outside app/."""

    def save(self, user: User) -> None: ...
    def exists(self, email: str) -> bool: ...
