from pydantic import BaseModel, EmailStr


class MobileLoginRequest(BaseModel):
    email: EmailStr
    password: str

    model_config = {"json_schema_extra": {"example": {"email": "user@example.com", "password": "secret"}}}


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
