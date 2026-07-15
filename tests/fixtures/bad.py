from os import *


def get(data, key):
    try:
        return data[key]  # type: ignore
    except:
        pass  # TODO: handle the missing key
