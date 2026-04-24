from datetime import datetime

from pydantic import BaseModel, EmailStr


class MeResponse(BaseModel):
    id: int
    email: str
    user_type: str  # CLIENT | AGENT | CORPORATE | ADMIN
    name: str | None = None
    signup_completed: bool = True
    created_at: datetime | None = None

    model_config = {"from_attributes": True}
