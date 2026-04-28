"""Менеджер WebSocket-подключений для live-сессий."""

from collections import defaultdict
from typing import Any

from fastapi import WebSocket


class SessionWebSocketManager:
    """Хранит активные подключения по session_id."""

    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = defaultdict(set)

    async def connect(self, session_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections[session_id].add(websocket)

    def disconnect(self, session_id: str, websocket: WebSocket) -> None:
        if session_id in self._connections:
            self._connections[session_id].discard(websocket)
            if not self._connections[session_id]:
                self._connections.pop(session_id, None)

    async def broadcast(self, session_id: str, event_type: str, data: dict[str, Any]) -> None:
        payload = {"type": event_type, "data": data}
        dead_connections: list[WebSocket] = []

        for ws in self._connections.get(session_id, set()):
            try:
                await ws.send_json(payload)
            except Exception:
                dead_connections.append(ws)

        for ws in dead_connections:
            self.disconnect(session_id, ws)

    def online_count(self, session_id: str) -> int:
        return len(self._connections.get(session_id, set()))


ws_manager = SessionWebSocketManager()
