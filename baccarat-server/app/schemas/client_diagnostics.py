"""Pydantic schemas for client diagnostics events."""

from pydantic import BaseModel, Field, field_validator


class ClientDiagnosticsRequest(BaseModel):
    event_type: str = Field(max_length=64)
    operation: str = Field(max_length=64)
    debug_reason: str = Field(max_length=64)
    error_message: str = Field(max_length=500)
    platform: str = Field(max_length=32)
    client_time_iso: str = Field(max_length=80)
    screen: str = Field(max_length=64)

    error_code: int | None = None
    app_version: str | None = Field(default=None, max_length=64)
    http_status_code: int | None = None
    request_start_code: int | None = None
    body_size: int | None = None
    response_was_empty: bool | None = None
    response_type: str | None = Field(default=None, max_length=64)
    api_base_url: str | None = Field(default=None, max_length=200)
    client_request_seq: int | None = None

    @field_validator(
        "event_type",
        "operation",
        "debug_reason",
        "platform",
        "client_time_iso",
        "screen",
        "app_version",
        "response_type",
        "api_base_url",
        mode="before",
    )
    @classmethod
    def normalize_optional_string(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = str(value).strip()
        if not normalized:
            return None
        return normalized

    @field_validator("error_message", mode="before")
    @classmethod
    def normalize_error_message(cls, value: str) -> str:
        normalized = str(value).strip()
        if not normalized:
            raise ValueError("error_message is required")
        return normalized
