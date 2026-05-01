"""Pydantic schemas for dealer room access activation."""

from datetime import datetime

from pydantic import BaseModel, Field


class DealerAccessActivateRequest(BaseModel):
    access_code: str
    display_name: str = Field(max_length=100)


class DealerInviteActivateRequest(BaseModel):
    invite_code: str
    display_name: str = Field(max_length=100)


class DealerAccessRoomResponse(BaseModel):
    id: str
    room_code: str
    name: str
    status: str


class DealerAccessDealerResponse(BaseModel):
    id: str
    display_name: str
    role: str = "dealer"


class DealerAccessInfoResponse(BaseModel):
    id: str
    kind: str = "room_access"
    slot_number: int | None = None
    status: str
    access_code_suffix: str | None = None
    trainer_internal_name: str | None = None
    activated_at: datetime | None = None


class DealerAccessActivateResponse(BaseModel):
    participant_token: str
    token_type: str = "Participant"
    room: DealerAccessRoomResponse
    dealer: DealerAccessDealerResponse
    access: DealerAccessInfoResponse


class DealerMyRoomsRequest(BaseModel):
    participant_tokens: list[str] = Field(max_length=50)


class DealerMyRoomRoomInfo(BaseModel):
    id: str
    room_code: str
    name: str
    status: str


class DealerMyRoomAccessInfo(BaseModel):
    id: str
    kind: str = "room_access"
    slot_number: int | None = None
    status: str
    access_code_suffix: str | None = None
    trainer_internal_name: str | None = None


class DealerMyRoomDealerInfo(BaseModel):
    id: str
    display_name: str


class DealerMyRoomActiveSessionInfo(BaseModel):
    id: str
    status: str


class DealerMyRoomItem(BaseModel):
    room: DealerMyRoomRoomInfo
    access: DealerMyRoomAccessInfo
    dealer: DealerMyRoomDealerInfo
    participant_token_status: str
    availability: str
    active_session: DealerMyRoomActiveSessionInfo | None = None


class InvalidParticipantTokenInfo(BaseModel):
    index: int
    reason: str


class DealerMyRoomsResponse(BaseModel):
    rooms: list[DealerMyRoomItem]
    invalid_tokens: list[InvalidParticipantTokenInfo]


class DealerTokenExchangeRequest(BaseModel):
    participant_token: str


class DealerTokenExchangeDealerInfo(BaseModel):
    id: str
    display_name: str
    room_id: str
    room_code: str


class DealerTokenExchangeAccessInfo(BaseModel):
    id: str
    kind: str = "room_access"
    status: str


class DealerTokenExchangeResponse(BaseModel):
    access_token: str
    token_type: str = "Bearer"
    expires_in: int
    dealer: DealerTokenExchangeDealerInfo
    access: DealerTokenExchangeAccessInfo
