import os
import pprint
import pytest
import testinfra
import logging

log = logging.getLogger(__name__)


@pytest.fixture(scope="session")
def host():
    if os.environ.get("KITCHEN_USERNAME") == "vagrant" or "windows" in os.environ.get(
        "KITCHEN_INSTANCE"
    ):
        if "windows" in os.environ.get("KITCHEN_INSTANCE"):
            return testinfra.get_host(
                "winrm://{KITCHEN_USERNAME}:{KITCHEN_PASSWORD}@{KITCHEN_HOSTNAME}:{KITCHEN_PORT}".format(
                    **os.environ
                ),
                no_ssl=True,
            )
        return testinfra.get_host(
            "paramiko://{KITCHEN_USERNAME}@{KITCHEN_HOSTNAME}:{KITCHEN_PORT}".format(
                **os.environ
            ),
            ssh_identity_file=os.environ.get("KITCHEN_SSH_KEY"),
        )
    return testinfra.get_host(
        "docker://{KITCHEN_USERNAME}@{KITCHEN_CONTAINER_ID}".format(**os.environ)
    )


@pytest.fixture(scope="session")
def target_python_version():
    target_python = os.environ["KITCHEN_SUITE"].split("-", 1)[0]
    if target_python == "latest":
        pytest.skip(
            "Unable to get target python from {}".format(os.environ["KITCHEN_SUITE"])
        )
    return int(target_python.replace("py", ""))


@pytest.fixture(scope="session")
def target_salt_version():
    target_salt = os.environ["KITCHEN_SUITE"].split("-", 2)[-1].replace("-", ".")
    if target_salt in ("latest", "master"):
        pytest.skip("Don't have a specific salt version to test against")
    return target_salt
