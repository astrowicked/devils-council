def format_timestamp(ts: int) -> str:
    import datetime
    return datetime.datetime.utcfromtimestamp(ts).isoformat()
