from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_S3_BUCKET: str = ""
    AWS_REGION: str = "ap-southeast-1"
    AWS_ENDPOINT: str = ""
    FACE_MATCH_THRESHOLD: float = 0.60
    FACE_NET_DEVICE: str = "cpu"

    # Email (Resend)
    RESEND_API_KEY: str = ""
    EMAIL_FROM: str = "Citadel <onboarding@resend.dev>"
    VERIFICATION_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours

    # Public-facing URL used for verification links
    BACKEND_URL: str = "http://localhost:8000"

    model_config = {"env_file": ".env"}


settings = Settings()
