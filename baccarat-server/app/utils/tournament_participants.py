import re


_MULTISPACE_RE = re.compile(r"\s+")


def clean_tournament_display_name(display_name: str) -> str:
    """Clean display name for user-facing tournament participant display."""
    trimmed = display_name.strip()
    return _MULTISPACE_RE.sub(" ", trimmed)


def normalize_tournament_display_name(display_name: str) -> str:
    """Normalize display name for tournament participant lookup."""
    return clean_tournament_display_name(display_name).casefold()
