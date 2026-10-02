import json
import logging
import os
import platform
import re
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


DEBIAN_REPO_FUNCTIONS = [
    "__install_saltstack_ubuntu_repository",
    "__install_saltstack_ubuntu_onedir_repository",
    "__install_saltstack_debian_repository",
    "__install_saltstack_debian_onedir_repository",
]

SAMPLE_SALT_SOURCES = """\
X-Repolib-Name: Salt Project
Types: deb
URIs: https://packages.broadcom.com/artifactory/saltproject-deb
Signed-By: /etc/apt/keyrings/salt-archive-keyring.pgp
Suites: stable
Components: main
"""


def _bash_has_gnu_sed():
    # Check through "bash -c", the exact invocation the test below uses, since
    # e.g. on GitHub's Windows runners plain "sed" on the host PATH is Git
    # Bash's GNU sed, but "bash" on the host PATH resolves to the WSL launcher
    # stub instead - a different, often broken, resolution path.
    try:
        result = subprocess.run(
            ["bash", "-c", "sed --version"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )
    except FileNotFoundError:
        return False
    return "GNU sed" in result.stdout


REPO_FILE_FUNCTIONS = DEBIAN_REPO_FUNCTIONS + [
    "__install_saltstack_rhel_onedir_repository",
    "__install_saltstack_fedora_onedir_repository",
]

SAMPLE_SALT_REPO = """[salt-repo-3006-lts]
name=Salt Repo for Salt v3006 LTS
baseurl=https://packages.broadcom.com/artifactory/saltproject-rpm/
skip_if_unavailable=True
priority=10
enabled=1
enabled_metadata=1
gpgcheck=1
exclude=*3007* *3008* *3009* *3010*
gpgkey=https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public

[salt-repo-latest]
name=Salt Repo for Salt LATEST release
baseurl=https://packages.broadcom.com/artifactory/saltproject-rpm/
skip_if_unavailable=True
priority=10
enabled=0
enabled_metadata=1
gpgcheck=1
gpgkey=https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public
"""


def _read_bootstrap_script():
    bootstrap_script = os.path.join(
        os.path.dirname(__file__), "..", "..", "bootstrap-salt.sh"
    )
    if not os.path.exists(bootstrap_script):
        pytest.skip("bootstrap-salt.sh not found (not running from a repo checkout)")
    with open(bootstrap_script) as fp:
        return fp.read()


def _extract_function(script, func_name):
    match = re.search(rf"^{re.escape(func_name)}\(\) {{.*?^}}", script, re.M | re.S)
    assert match, f"could not find {func_name}() in bootstrap-salt.sh"
    return match.group(0)


def _run_rewrite_repo_url(tmp_path, script, repo_file, repo_url):
    # Run from a file; passing this through "bash -c" mangles quoting on Windows
    shell = "\n".join(
        [
            f'_REPO_URL="{repo_url}"',
            _extract_function(script, "__rewrite_repo_url"),
            '__rewrite_repo_url "$1"',
        ]
    )
    with open(str(tmp_path / "rewrite.sh"), "w", newline="\n") as fp:
        fp.write(shell + "\n")
    # Relative paths, since backslashes in Windows paths get mangled by bash
    subprocess.run(
        ["bash", "rewrite.sh", repo_file.name],
        cwd=str(tmp_path),
        check=True,
    )


def test_repo_functions_call_rewrite_repo_url():
    """
    Every function that downloads a repo definition from salt-install-guide must
    rewrite it for -R/_CUSTOM_REPO_URL, otherwise the system keeps pointing at
    packages.broadcom.com (issues #2123, #2135).
    """
    script = _read_bootstrap_script()

    # Discover rather than rely on a hand-kept list, so new distro functions that
    # download a repo definition are covered automatically. Commented-out fetches
    # (e.g. Photon) are ignored.
    discovered = set()
    for match in re.finditer(r"^(\w+)\(\) {.*?^}", script, re.M | re.S):
        code = "\n".join(
            line
            for line in match.group(0).splitlines()
            if not line.lstrip().startswith("#")
        )
        if "salt-install-guide/releases" in code:
            discovered.add(match.group(1))

    # Guard against the discovery silently matching nothing
    missing = set(REPO_FILE_FUNCTIONS) - discovered
    assert not missing, f"repo discovery missed known functions: {sorted(missing)}"

    for func_name in sorted(discovered):
        body = _extract_function(script, func_name)
        assert (
            "__rewrite_repo_url" in body
        ), f"{func_name} downloads a repo file but does not call __rewrite_repo_url"


def test_debian_repo_files_rewrite_custom_repo_url(tmp_path):
    """
    Regression test for https://github.com/saltstack/salt-bootstrap/issues/2123
    The -R/_CUSTOM_REPO_URL option must rewrite the "URIs:" line in
    salt.sources for Debian/Ubuntu, not just the GPG key fetch URL.
    """
    if not _bash_has_gnu_sed():
        # bootstrap-salt.sh's sed -i syntax targets GNU sed, which is what these
        # distros actually ship. BSD sed (e.g. on macOS) parses "-i" differently,
        # and isn't representative of the real target either way.
        pytest.skip("bash with GNU sed not available")
    script = _read_bootstrap_script()

    sources_file = tmp_path / "salt.sources"
    with open(str(sources_file), "w", newline="\n") as fp:
        fp.write(SAMPLE_SALT_SOURCES)
    _run_rewrite_repo_url(tmp_path, script, sources_file, "repo.example.com/myrepo")

    result = sources_file.read_text()
    assert "packages.broadcom.com" not in result, result
    assert "URIs: https://repo.example.com/myrepo/saltproject-deb" in result


def test_rpm_repo_file_rewrite_custom_repo_url(tmp_path):
    """
    Regression test for https://github.com/saltstack/salt-bootstrap/issues/2135
    The -R/_CUSTOM_REPO_URL option must rewrite every baseurl= and gpgkey= in
    the downloaded salt.repo for RHEL/CentOS/Fedora.
    """
    if not _bash_has_gnu_sed():
        pytest.skip("bash with GNU sed not available")
    script = _read_bootstrap_script()

    repo_file = tmp_path / "salt.repo"
    with open(str(repo_file), "w", newline="\n") as fp:
        fp.write(SAMPLE_SALT_REPO)
    # "&" and "#" are special in the sed replacement/delimiter
    _run_rewrite_repo_url(tmp_path, script, repo_file, "repo.example.com/my&repo#1")

    result = repo_file.read_text()
    assert "packages.broadcom.com" not in result, result
    assert result.count("baseurl=https://repo.example.com/my&repo#1/saltproject-rpm/") == 2
    assert (
        result.count(
            "gpgkey=https://repo.example.com/my&repo#1/api/security/keypair/SaltProjectKey/public"
        )
        == 2
    )
    # Only the URLs change; sections and their enabled state are preserved
    assert "[salt-repo-3006-lts]" in result and "[salt-repo-latest]" in result
    assert result.count("enabled=1") == 1 and result.count("enabled=0") == 1


DETECTION_FUNCTIONS = [
    "__gather_linux_system_info",
    "__sort_release_files",
    "__parse_version_string",
    "__unquote_string",
    "__derive_debian_numeric_version",
    "__camelcase_split",
]


@pytest.mark.parametrize(
    "os_id,version_id,os_name,expected",
    [
        ("photon", "5.0", "VMware Photon OS", "vmware_photon_os"),
        ("photon", "4.0", "VMware Photon OS", "vmware_photon_os"),
        ("altlinux", "11", "ALT Server", "alt_linux"),
        ("alpine", "3.20.3", "Alpine Linux", "alpine_linux"),
    ],
)
def test_os_release_id_resolves_to_install_functions(
    tmp_path, os_id, version_id, os_name, expected
):
    """
    Regression test for UBMVCFOPS-14333
    When /etc/lsb-release is absent, distro detection falls back to the ID= in
    /etc/os-release. The resulting DISTRO_NAME_L must match the name used by
    the distro's install_* functions, or bootstrap exits with "No dependencies
    installation function found."
    """
    if not _bash_has_gnu_sed():
        pytest.skip("bash with GNU sed not available")

    bootstrap_script = os.path.join(
        os.path.dirname(__file__), "..", "..", "bootstrap-salt.sh"
    )
    if not os.path.exists(bootstrap_script):
        pytest.skip("bootstrap-salt.sh not found (not running from a repo checkout)")

    with open(bootstrap_script) as fp:
        script = fp.read()

    funcs = []
    for func_name in DETECTION_FUNCTIONS:
        match = re.search(rf"^{re.escape(func_name)}\(\) {{.*?^}}", script, re.M | re.S)
        assert match, f"could not find {func_name}() in bootstrap-salt.sh"
        funcs.append(match.group(0))

    name_l_match = re.search(r"^DISTRO_NAME_L=.*$", script, re.M)
    assert name_l_match, "could not find DISTRO_NAME_L assignment in bootstrap-salt.sh"

    fake_etc = tmp_path / "etc"
    fake_etc.mkdir()
    # open() rather than write_text(newline=), which needs Python 3.10+
    with open(str(fake_etc / "os-release"), "w", newline="\n") as fp:
        fp.write(f'NAME="{os_name}"\nID={os_id}\nVERSION_ID={version_id}\n')

    # Keep the host's lsb_release from short-circuiting os-release detection
    shell = "\n".join(
        ["FAKE_ETC=etc", "lsb_release() { return 1; }"]
        + [func.replace("/etc", "${FAKE_ETC}") for func in funcs]
        + [
            "__gather_linux_system_info",
            name_l_match.group(0),
            'echo "$DISTRO_NAME_L"',
        ]
    )
    # Run from a file; passing this through "bash -c" mangles quoting on Windows
    with open(str(tmp_path / "detect.sh"), "w", newline="\n") as fp:
        fp.write(shell + "\n")

    result = subprocess.run(
        ["bash", "detect.sh"],
        cwd=str(tmp_path),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    assert result.returncode == 0, result.stderr
    distro_name_l = result.stdout.strip()
    assert distro_name_l == expected

    assert re.search(
        rf"^install_{re.escape(distro_name_l)}_\w*deps\(\)", script, re.M
    ), f"no install_{distro_name_l}_*deps() in bootstrap-salt.sh"
