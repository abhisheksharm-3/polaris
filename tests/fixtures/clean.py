"""Lookup helpers for the fixture suite."""


def get(data, key):
    """Returns the value at key, or None when the key is absent."""
    try:
        return data[key]
    except KeyError:
        return None
