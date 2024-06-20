#!/usr/bin/env python3
import datetime
import json
import os
import pathlib

os.chdir(os.path.abspath(os.path.dirname(__file__)))

LINUX_DISTROS = [
    "almalinux-8",
    "almalinux-9",
    "amazon-2",
    "amazon-2023",
    "arch",
    "centos-stream8",
    "centos-stream9",
    "debian-11",
    "debian-12",
    "fedora-39",
    "fedora-40",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "oraclelinux-8",
    "oraclelinux-9",
    "photon-4",
    "photon-5",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2204",
    "ubuntu-2404",
]
WINDOWS = [
    "windows-2019",
    "windows-2022",
]

OSX = [
    "macos-12",
    "macos-13",
]


STABLE_DISTROS = [
    "almalinux-8",
    "almalinux-9",
    "amazon-2",
    "amazon-2023",
    "arch",
    "centos-stream8",
    "centos-stream9",
    "debian-11",
    "debian-12",
    "fedora-39",
    "fedora-40",
    "opensuse-15",
    "opensuse-tumbleweed",
    "oraclelinux-7",
    "oraclelinux-8",
    "oraclelinux-9",
    "photon-4",
    "photon-5",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2204",
    "ubuntu-2404",
]

ONEDIR_DISTROS = [
    "almalinux-8",
    "almalinux-9",
    "amazon-2",
    "amazon-2023",
    "centos-stream8",
    "centos-stream9",
    "debian-11",
    "debian-12",
    "fedora-39",
    "fedora-40",
    "oraclelinux-7",
    "oraclelinux-8",
    "oraclelinux-9",
    "photon-4",
    "photon-5",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2204",
    "ubuntu-2404",
]

ONEDIR_RC_DISTROS = [
    "almalinux-9",
    "amazon-2",
    "amazon-2023",
    "centos-stream9",
    "debian-12",
    "oraclelinux-9",
    "photon-4",
    "photon-5",
    "rockylinux-9",
    "ubuntu-2404",
]

BLACKLIST_3006 = [
    "arch",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
]

BLACKLIST_GIT_3006 = [
    "almalinux-9",
    "amazon-2",
    "arch",
    "centos-stream9",
    "debian-11",
    "debian-12",
    "fedora-39",
    "fedora-40",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "photon-4",
    "photon-5",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2204",
    "ubuntu-2310",
    "ubuntu-2404",
]

BLACKLIST_GIT_MASTER = [
    "amazon-2",
]

SALT_VERSIONS = [
    "3006",
    "3006-8",
    "master",
    "latest",
    "nightly",
]

ONEDIR_SALT_VERSIONS = [
    "3006",
    "latest",
]

ONEDIR_RC_SALT_VERSIONS = []

VERSION_DISPLAY_NAMES = {
    "3006": "v3006",
    "3006-8": "v3006.8",
    "master": "Master",
    "latest": "Latest",
    "nightly": "Nightly",
}

STABLE_VERSION_BLACKLIST = [
    "master",
    "nightly",
]

MAC_STABLE_VERSION_BLACKLIST = [
    "master",
    "nightly",
]

GIT_VERSION_BLACKLIST = [
    "3006-8",
    "nightly",
]

# TODO: Revert the commit relating to this section, once the Git-based builds
#       have been fixed for the distros listed below
#
#       Apparent failure is:
#
#           /usr/lib/python3.11/site-packages/setuptools/command/install.py:34:
#           SetuptoolsDeprecationWarning: setup.py install is deprecated.
#           Use build and pip and other standards-based tools.
#
GIT_DISTRO_BLACKLIST = [
    "almalinux-8",
    "centos-stream8",
    "fedora-39",
    "fedora-40",
    "opensuse-15",
    "oraclelinux-7",
    "oraclelinux-8",
    "oraclelinux-9",
    "rockylinux-8",
]

LATEST_PKG_BLACKLIST = [
    "gentoo",
    "gentoo-systemd",
]

DISTRO_DISPLAY_NAMES = {
    "almalinux-8": "AlmaLinux 8",
    "almalinux-9": "AlmaLinux 9",
    "amazon-2": "Amazon 2",
    "amazon-2023": "Amazon 2023",
    "arch": "Arch",
    "centos-stream8": "CentOS Stream 8",
    "centos-stream9": "CentOS Stream 9",
    "debian-11": "Debian 11",
    "debian-12": "Debian 12",
    "fedora-39": "Fedora 39",
    "fedora-40": "Fedora 40",
    "gentoo": "Gentoo",
    "gentoo-systemd": "Gentoo (systemd)",
    "opensuse-15": "Opensuse 15",
    "opensuse-tumbleweed": "Opensuse Tumbleweed",
    "oraclelinux-8": "Oracle Linux 8",
    "oraclelinux-9": "Oracle Linux 9",
    "photon-4": "Photon OS 4",
    "photon-5": "Photon OS 5",
    "rockylinux-8": "Rocky Linux 8",
    "rockylinux-9": "Rocky Linux 9",
    "ubuntu-2004": "Ubuntu 20.04",
    "ubuntu-2204": "Ubuntu 22.04",
    "ubuntu-2404": "Ubuntu 24.04",
    "macos-12": "macOS 12",
    "macos-13": "macOS 13",
    "windows-2019": "Windows 2019",
    "windows-2022": "Windows 2022",
}

TIMEOUT_DEFAULT = 20
TIMEOUT_OVERRIDES = {
    "gentoo": 90,
    "gentoo-systemd": 90,
}
VERSION_ONLY_OVERRIDES = [
    "gentoo",
    "gentoo-systemd",
]

TEMPLATE = """
  {distro}:
    name: {display_name}{ifcheck}
    uses: {uses}
    needs:
      - lint
      - generate-actions-workflow
    with:
      distro-slug: {distro}
      display-name: {display_name}
      timeout: {timeout_minutes}{runs_on}
      instances: '{instances}'
"""


def generate_test_jobs():
    test_jobs = ""
    needs = ["lint", "generate-actions-workflow"]

    test_jobs += "\n"
    for distro in OSX:
        test_jobs += "\n"
        runs_on = distro
        runs_on = f"\n      runs-on: {runs_on}"
        ifcheck = "\n    if: github.event_name == 'push' || needs.collect-changed-files.outputs.run-tests == 'true'"
        uses = "./.github/workflows/test-macos.yml"
        instances = []
        timeout_minutes = (
            TIMEOUT_OVERRIDES[distro]
            if distro in TIMEOUT_OVERRIDES
            else TIMEOUT_DEFAULT
        )

        for salt_version in SALT_VERSIONS:
            if salt_version == "latest":
                instances.append(salt_version)
                continue

            for bootstrap_type in ["stable"]:
                if bootstrap_type == "stable":
                    if salt_version in MAC_STABLE_VERSION_BLACKLIST:
                        continue

                test_target = f"{bootstrap_type}-{salt_version}"
                instances.append(test_target)

        for bootstrap_type in ["default"]:
            if distro not in STABLE_DISTROS:
                continue
            instances.append(bootstrap_type)

        if instances:
            needs.append(distro)
            test_jobs += TEMPLATE.format(
                distro=distro,
                runs_on=runs_on,
                uses=uses,
                ifcheck=ifcheck,
                instances=json.dumps(instances),
                display_name=DISTRO_DISPLAY_NAMES[distro],
                timeout_minutes=timeout_minutes,
            )

    test_jobs += "\n"
    for distro in WINDOWS:
        test_jobs += "\n"
        runs_on = f"\n      runs-on: {distro}"
        ifcheck = "\n    if: github.event_name == 'push' || needs.collect-changed-files.outputs.run-tests == 'true'"
        uses = "./.github/workflows/test-windows.yml"
        instances = []
        timeout_minutes = (
            TIMEOUT_OVERRIDES[distro]
            if distro in TIMEOUT_OVERRIDES
            else TIMEOUT_DEFAULT
        )

        for salt_version in SALT_VERSIONS:

            if salt_version == "latest":

                instances.append(salt_version)
                continue

            for bootstrap_type in ["stable"]:
                if bootstrap_type == "stable":
                    if salt_version in STABLE_VERSION_BLACKLIST:
                        continue

                test_target = f"{bootstrap_type}-{salt_version}"
                instances.append(test_target)

        for bootstrap_type in ["default"]:
            if distro not in STABLE_DISTROS:
                continue
            instances.append(bootstrap_type)

        if instances:
            needs.append(distro)
            test_jobs += TEMPLATE.format(
                distro=distro,
                runs_on=runs_on,
                uses=uses,
                ifcheck=ifcheck,
                instances=json.dumps(instances),
                display_name=DISTRO_DISPLAY_NAMES[distro],
                timeout_minutes=timeout_minutes,
            )

    test_jobs += "\n"
    for distro in LINUX_DISTROS:
        test_jobs += "\n"
        runs_on = ""
        ifcheck = "\n    if: github.event_name == 'push' || needs.collect-changed-files.outputs.run-tests == 'true'"
        uses = "./.github/workflows/test-linux.yml"
        instances = []
        timeout_minutes = (
            TIMEOUT_OVERRIDES[distro]
            if distro in TIMEOUT_OVERRIDES
            else TIMEOUT_DEFAULT
        )
        if distro in VERSION_ONLY_OVERRIDES:
            ifcheck = "\n    if: github.event_name == 'push'"

        for salt_version in SALT_VERSIONS:

            if salt_version == "latest":
                if distro in LATEST_PKG_BLACKLIST:
                    continue

                instances.append(salt_version)
                continue

            for bootstrap_type in (
                "stable",
                "git",
                "onedir",
                "onedir-rc",
            ):
                if bootstrap_type == "onedir":
                    if salt_version not in ONEDIR_SALT_VERSIONS:
                        continue
                    if distro not in ONEDIR_DISTROS:
                        continue

                if bootstrap_type == "onedir-rc":
                    if salt_version not in ONEDIR_RC_SALT_VERSIONS:
                        continue
                    if distro not in ONEDIR_RC_DISTROS:
                        continue

                if bootstrap_type == "stable":
                    if salt_version in STABLE_VERSION_BLACKLIST:
                        continue
                    if distro not in STABLE_DISTROS:
                        continue

                if bootstrap_type == "git":
                    if salt_version in GIT_VERSION_BLACKLIST:
                        continue
                    if distro in GIT_DISTRO_BLACKLIST:
                        continue

                BLACKLIST = {
                    "3006": BLACKLIST_3006,
                    "3006-8": BLACKLIST_3006,
                }
                if bootstrap_type == "git":
                    BLACKLIST = {
                        "3006": BLACKLIST_GIT_3006,
                        "master": BLACKLIST_GIT_MASTER,
                    }

                    # .0 versions are a virtual version for pinning to the first
                    # point release of a major release, such as 3003,
                    # there is no git version.
                    if salt_version.endswith("-0"):
                        continue

                if (
                    salt_version in ("3006", "3006-8", "master")
                    and distro in BLACKLIST[salt_version]
                ):
                    continue

                test_target = f"{bootstrap_type}-{salt_version}"
                instances.append(test_target)

        for bootstrap_type in ["default"]:
            if distro not in STABLE_DISTROS:
                continue
            instances.append(bootstrap_type)

        if instances:
            needs.append(distro)
            test_jobs += TEMPLATE.format(
                distro=distro,
                runs_on=runs_on,
                uses=uses,
                ifcheck=ifcheck,
                instances=json.dumps(instances),
                display_name=DISTRO_DISPLAY_NAMES[distro],
                timeout_minutes=timeout_minutes,
            )

    ci_src_workflow = pathlib.Path("ci.yml").resolve()
    ci_tail_src_workflow = pathlib.Path("ci-tail.yml").resolve()
    ci_dst_workflow = pathlib.Path("../ci.yml").resolve()
    ci_workflow_contents = ci_src_workflow.read_text() + test_jobs + "\n"
    ci_workflow_contents += ci_tail_src_workflow.read_text().format(
        needs="\n".join([f"      - {need}" for need in needs]).lstrip()
    )
    ci_dst_workflow.write_text(ci_workflow_contents)


if __name__ == "__main__":
    generate_test_jobs()
