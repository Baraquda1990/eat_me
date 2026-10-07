from django.core.files.storage import storages


def get_private_storage():
    return storages["private"]
