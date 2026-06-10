from dataclasses import dataclass


@dataclass(frozen=True)
class User:
    email: str
    name: str
