def normalize_url(url: str) -> str:
    """Strip trailing slash and lowercase the host."""
    return url.lower().rstrip("/")
