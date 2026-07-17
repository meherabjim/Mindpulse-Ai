from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.core.config import get_settings
from app.models.schemas import HealthResponse


settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description=(
        "Explainable wellness analysis and safety-support "
        "service for MindPulse AI."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins,
    allow_credentials=False,
    allow_methods=[
        "GET",
        "POST",
    ],
    allow_headers=[
        "Content-Type",
        "X-Internal-API-Key",
    ],
)

app.include_router(router)


@app.get("/")
async def root() -> dict[str, object]:
    return {
        "success": True,
        "message": (
            "Welcome to MindPulse AI Service"
        ),
        "data": {
            "version": "1.0.0",
        },
    }


@app.get(
    "/health",
    response_model=HealthResponse,
)
async def health() -> HealthResponse:
    return HealthResponse(
        success=True,
        service=settings.app_name,
        status="healthy",
        environment=settings.environment,
    )
