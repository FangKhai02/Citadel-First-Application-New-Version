import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1.router import router
from app.core.database import Base, engine

# Register all models so metadata is populated before create_all
import app.models.user   # noqa: F401
import app.models.signup  # noqa: F401  – registers BankruptcyDeclaration, DisclaimerAcceptance
import app.models.user_details  # noqa: F401  – registers UserDetails
import app.models.face_verification  # noqa: F401  – registers FaceVerification
import app.models.pep_declaration  # noqa: F401  – registers PepDeclaration
import app.models.crs_tax_residency  # noqa: F401  – registers CrsTaxResidency
import app.models.beneficiary  # noqa: F401  – registers Beneficiary

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)


@asynccontextmanager
async def lifespan(_: FastAPI):
    async with engine.begin() as conn:
        # Creates new tables only; existing tables are left untouched
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    title="Citadel First API",
    description="REST API for the Citadel First wealth management platform. "
    "Swagger UI is available at /docs, ReDoc at /redoc.",
    version="1.0.0",
    contact={"name": "Citadel Group", "email": "dev@citadelgroup.com.my"},
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tighten this to specific domains in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)

_static_dir = Path(__file__).parent / "static"
if _static_dir.is_dir():
    app.mount("/static", StaticFiles(directory=str(_static_dir)), name="static")


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "ok", "service": "citadel-first-api"}
