"""Public endpoint for minimal client diagnostics events."""

from fastapi import APIRouter

from app.schemas.client_diagnostics import ClientDiagnosticsRequest


router = APIRouter(prefix="/client-diagnostics")


@router.post("")
async def create_client_diagnostics_event(payload: ClientDiagnosticsRequest) -> dict[str, bool]:
    print(
        "CLIENT_DIAGNOSTICS "
        f"event_type={payload.event_type} "
        f"operation={payload.operation} "
        f"debug_reason={payload.debug_reason} "
        f"platform={payload.platform} "
        f"screen={payload.screen} "
        f"client_time_iso={payload.client_time_iso} "
        f"error_code={payload.error_code} "
        f"http_status_code={payload.http_status_code} "
        f"request_start_code={payload.request_start_code} "
        f"body_size={payload.body_size} "
        f"response_was_empty={payload.response_was_empty} "
        f"response_type={payload.response_type} "
        f"client_request_seq={payload.client_request_seq} "
        f"app_version={payload.app_version} "
        f"api_base_url={payload.api_base_url} "
        f"error_message={payload.error_message}"
    )
    return {"ok": True}
