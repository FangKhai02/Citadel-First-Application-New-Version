from pydantic import BaseModel, Field


class SelfiePresignedUrlRequest(BaseModel):
    filename: str
    content_type: str = "image/jpeg"


class SelfiePresignedUrlResponse(BaseModel):
    upload_url: str
    key: str


class FaceVerifyRequest(BaseModel):
    selfie_image_key: str
    doc_image_key: str


class FaceVerifyResponse(BaseModel):
    id: int
    app_user_id: int
    is_match: bool
    confidence: float = Field(ge=0.0, le=1.0)
    distance: float | None = None
    selfie_face_detected: bool
    doc_face_detected: bool
    message: str

    model_config = {"from_attributes": True}


class FaceDetectRequest(BaseModel):
    selfie_image_key: str


class FaceDetectResponse(BaseModel):
    face_detected: bool
    face_count: int = 0
    message: str