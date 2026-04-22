import re
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator


class MobileLoginRequest(BaseModel):
    email: EmailStr
    password: str

    model_config = {"json_schema_extra": {"example": {"email": "user@example.com", "password": "secret"}}}


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    user_type: Literal["CLIENT", "AGENT", "CORPORATE"]

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-=+\[\]\\\/~`]', v):
            raise ValueError("Password must contain at least one special character")
        return v

    model_config = {
        "json_schema_extra": {
            "example": {"email": "user@example.com", "password": "Str0ng!Pass", "user_type": "CLIENT"}
        }
    }


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str

    model_config = {"json_schema_extra": {"example": {"email": "admin@citadelgroup.com.my", "password": "secret"}}}


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_type: str  # CLIENT | AGENT | CORPORATE | ADMIN
    user_id: int


class RefreshRequest(BaseModel):
    refresh_token: str


class MessageResponse(BaseModel):
    message: str
