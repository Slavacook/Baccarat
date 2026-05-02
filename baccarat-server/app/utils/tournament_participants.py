import re


_MULTISPACE_RE = re.compile(r"\s+")


def normalize_tournament_display_name(display_name: str) -> str:
    """Normalize display name for tournament participant lookup."""
    trimmed = display_name.strip()
    collapsed = _MULTISPACE_RE.sub(" ", trimmed)
    return collapsed.casefold()
