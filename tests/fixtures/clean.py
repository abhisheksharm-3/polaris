def get(data, key):
    try:
        return data[key]
    except KeyError:
        return None
