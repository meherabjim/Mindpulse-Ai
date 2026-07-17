from secrets import compare_digest
from typing import Annotated

from fastapi import Header, HTTPException, status

from app.core.config import get_settings


async def verify_internal_api_key(
    x_internal_api_key: Annotated[
        str | None,
        Header(alias="X-Internal-API-Key"),
    ] = None,
) -> None:
    settings = get_settings()

    valid_key = (
        x_internal_api_key is not None
        and compare_digest(
            x_internal_api_key,
            settings.internal_api_key,
        )
    )

    if not valid_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing internal API key.",
        )
