import json
import logging
import os
import platform
import shutil
import subprocess

import pytest

log = logging.getLogger(__name__)


@pytest.fixture
def path():
    if platform.system() == "Windows":
        salt_path = "C:\\Program Files\\Salt Project\\Salt"
        if salt_path not in os.environ["path"]:
            os.environ["path"] = f'{os.environ["path"]};{salt_path}'
        yield os.environ["path"]
    else:
        yield ""


def run_salt_call(cmd):
    """
    Runs salt call command and returns a dictionary
    Accepts cmd as a list
    """
    json_data = {"local": {}}
    if platform.system() == "Windows":
        cmd.append("--out=json")
        result = subprocess.run(cmd, capture_output=True, text=True)
        if 0 == result.returncode:
            json_data = json.loads(result.stdout)
        else:
            log.error(f"failed to produce output result, '{result}'")

    else:
        if platform.system() == "Darwin":
            cmdl = ["sudo"]
        else:
            cmdl = []
        cmdl.extend(cmd)
        cmdl.append("--out=json")
        try:
            result = subprocess.run(cmdl, capture_output=True, text=True)
        except TypeError:
            result = subprocess.run(
                cmdl,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
            )
        if 0 == result.returncode:
            json_data = json.loads(result.stdout)
        else:
            log.error(f"failed to produce output result, '{result}'")

    return json_data["local"]


def test_ping(path):
    cmd = ["salt-call", "--local", "test.ping"]
    result = run_salt_call(cmd)
    assert result == True


def test_target_python_version(path, target_python_version):
    cmd = ["salt-call", "--local", "grains.item", "pythonversion", "--timeout=120"]
    result = run_salt_call(cmd)
    # Returns: {'pythonversion': [3, 10, 11, 'final', 0]}
    py_maj_ver = result["pythonversion"][0]
    assert py_maj_ver == target_python_version


def test_target_salt_version(path, target_salt_version):
    if not target_salt_version:
        pytest.skip(f"No target version specified")
    cmd = ["salt-call", "--local", "grains.item", "saltversion", "--timeout=120"]
    result = run_salt_call(cmd)
    # Returns: {'saltversion': '3006.9+217.g53cfa53040'}
    adj_saltversion = result["saltversion"].split("+")[0]
    assert adj_saltversion == target_salt_version


def test_apt_keyring_is_trusted():
    """
    Regression test for https://github.com/saltstack/salt/issues/69740
    apt only recognizes .gpg (binary) or .asc (armored) keyring files. A
    keyring referenced by an extension apt doesn't recognize is silently
    ignored, which apt reports as a NO_PUBKEY / unsigned-repository error.
    """
    if platform.system() != "Linux" or shutil.which("apt-get") is None:
        pytest.skip("Not an apt-based system")

    sources_file = "/etc/apt/sources.list.d/salt.sources"
    if not os.path.exists(sources_file):
        pytest.skip("No salt.sources file present")

    signed_by = None
    with open(sources_file) as fp:
        for line in fp:
            if line.strip().startswith("Signed-By:"):
                signed_by = line.split(":", 1)[1].strip()
                break

    assert signed_by, "salt.sources has no Signed-By line"
    assert os.path.exists(signed_by), f"Signed-By keyring {signed_by} does not exist"
    assert signed_by.endswith(
        ".gpg"
    ), f"apt does not recognize {signed_by}'s extension as a valid keyring"

    # Confirm the keyring is actually binary GPG data, not raw ASCII-armored text
    file_result = subprocess.run(
        ["file", signed_by], capture_output=True, text=True
    )
    assert "PGP public key block" not in file_result.stdout, file_result.stdout

    result = subprocess.run(["apt-get", "update"], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    assert "NO_PUBKEY" not in result.stderr, result.stderr
    assert "unsupported filetype" not in result.stderr, result.stderr
