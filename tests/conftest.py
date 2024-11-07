import json
import os

import pytest
import requests

API_URL = (
    "https://packages.broadcom.com/artifactory/api/storage/saltproject-generic/windows"
)


@pytest.fixture(scope="session")
def target_python_version():
    return 3


@pytest.fixture(scope="session")
def target_salt_version():

    target_salt = os.environ.get("SaltVersion", "")

    html_response = requests.get(API_URL)
    content = json.loads(html_response.text)
    folders = content["children"]
    versions = {}
    for folder in folders:
        if folder["folder"]:
            version = folder["uri"].strip("/")
            versions[version] = version
            # We're trying to get the latest major version and latest overall
            maj_version = version.split(".")[0]
            versions[maj_version] = version
            versions["latest"] = version

    if target_salt.startswith("v"):
        target_salt = target_salt[1:]
    if target_salt not in versions:
        pytest.skip(f"Invalid testing version: {target_salt}")
    if target_salt in ("default", "latest", "master", "nightly"):
        pytest.skip("Don't have a specific salt version to test against")
    return versions[target_salt]
