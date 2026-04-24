from pydantic import BaseModel


class PepDeclarationRequest(BaseModel):
    is_pep: bool
    pep_relationship: str | None = None  # SELF, FAMILY, ASSOCIATE
    pep_name: str | None = None
    pep_position: str | None = None
    pep_organisation: str | None = None
    pep_supporting_doc_key: str | None = None


class PepDeclarationResponse(BaseModel):
    id: int
    app_user_id: int
    is_pep: bool
    pep_relationship: str | None
    pep_name: str | None
    pep_position: str | None
    pep_organisation: str | None
    pep_supporting_doc_key: str | None

    model_config = {"from_attributes": True}