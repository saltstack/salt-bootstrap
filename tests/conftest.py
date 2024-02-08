import logging
import os
import pprint

import pytest
import testinfra

log = logging.getLogger(__name__)


@pytest.fixture(scope="session")
def host():
    if (
        os.environ.get("RUNNER_OS", "") == "macOS"
        and os.environ.get("KITCHEN_LOCAL_YAML", "") == "kitchen.macos.yml"
    ):
        # Adjust the `PATH` so that the `salt-call` executable can be found
        os.environ["PATH"] = "/opt/salt/bin{}{}".format(os.pathsep, os.environ["PATH"])
        return testinfra.get_host("local://", sudo=True)

    if os.environ.get("KITCHEN_USERNAME") == "vagrant" or "windows" in os.environ.get(
        "KITCHEN_INSTANCE"
    ):
        if "windows" in os.environ.get("KITCHEN_INSTANCE"):
            _url = "winrm://{KITCHEN_USERNAME}:{KITCHEN_PASSWORD}@{KITCHEN_HOSTNAME}:{KITCHEN_PORT}".format(
                **os.environ
            )
            return testinfra.get_host(
                _url,
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
    return 3


@pytest.fixture(scope="session")
def target_salt_version():
    bootstrap_types = ("git", "stable", "onedir", "onedir_rc")

    # filter out any bootstrap types and then join
    target_salt = ".".join(
        [
            item
            for item in os.environ["KITCHEN_SUITE"].split("-")
            if item not in bootstrap_types
        ]
    )

    # target_salt = os.environ["KITCHEN_SUITE"].split("-", 1)[-1].replace("-", ".")

    if target_salt.startswith("v"):
        target_salt = target_salt[1:]
    if target_salt in ("default", "latest", "master", "nightly"):
        pytest.skip("Don't have a specific salt version to test against")
    return target_salt
