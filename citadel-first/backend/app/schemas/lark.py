"""Pydantic models for Lark (Bitable) API responses."""


from pydantic import BaseModel


class LarkTokenResponse(BaseModel):
    tenant_access_token: str
    expire: int


class LarkBatchCreateResponse(BaseModel):
    code: int
    msg: str
    data: dict  # Contains "records" list with "record_id"


class LarkUploadResponse(BaseModel):
    code: int
    msg: str
    data: dict  # Contains "file_token"