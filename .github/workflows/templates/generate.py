#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os
import json
import pathlib
import datetime

os.chdir(os.path.abspath(os.path.dirname(__file__)))

LINUX_DISTROS = [
    "almalinux-8",
    "amazon-2",
    "arch",
    "centos-7",
    "centos-stream8",
    "debian-10",
    "debian-11",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "oraclelinux-7",
    "oraclelinux-8",
    "rockylinux-8",
    "ubuntu-1804",
    "ubuntu-2004",
    "ubuntu-2204",
]
WINDOWS = [
    "windows-2019",
    "windows-2022",
]

OSX = [
    "macos-1015",
    "macos-11",
    "macos-12",
]
BSD = [
    "freebsd-131",
    "freebsd-123",
    "openbsd-6",
]

STABLE_DISTROS = [
    "almalinux-8",
    "amazon-2",
    "arch",
    "centos-7",
    "centos-stream8",
    "debian-10",
    "debian-11",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "oraclelinux-7",
    "oraclelinux-8",
    "rockylinux-8",
    "ubuntu-1804",
    "ubuntu-2004",
    "ubuntu-2204",
]

BLACKLIST_3003 = [
    "arch",
    "debian-11",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "rockylinux-8",
    "ubuntu-2204",
]

BLACKLIST_GIT_3003 = [
    "amazon-2",
    "arch",
    "debian-10",
    "debian-11",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "rockylinux-8",
    "ubuntu-2004",
    "ubuntu-2110",
    "ubuntu-2204",
]

BLACKLIST_3004 = [
    "arch",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
]

BLACKLIST_3005 = [
    "arch",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
]

BLACKLIST_GIT_3004 = [
    "amazon-2",
    "arch",
    "debian-10",
    "debian-11",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "ubuntu-2004",
    "ubuntu-2110",
    "ubuntu-2204",
]

BLACKLIST_GIT_3005 = [
    "amazon-2",
    "arch",
    "debian-10",
    "debian-11",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "ubuntu-2004",
    "ubuntu-2110",
    "ubuntu-2204",
]

SALT_VERSIONS = [
    "3003",
    "3004",
    "3005",
    "master",
    "latest",
]

ONEDIR_SALT_VERSIONS = [
    "3005",
    "latest",
]

VERSION_DISPLAY_NAMES = {
    "3003": "v3003",
    "3004": "v3004",
    "3005": "v3005",
    "master": "Master",
    "latest": "Latest",
}

STABLE_VERSION_BLACKLIST = []

LATEST_PKG_BLACKLIST = []

DISTRO_DISPLAY_NAMES = {
    "almalinux-8": "AlmaLinux 8",
    "amazon-2": "Amazon 2",
    "arch": "Arch",
    "centos-7": "CentOS 7",
    "centos-stream8": "CentOS Stream 8",
    "debian-10": "Debian 10",
    "debian-11": "Debian 11",
    "fedora-35": "Fedora 35",
    "fedora-36": "Fedora 36",
    "gentoo": "Gentoo",
    "gentoo-systemd": "Gentoo (systemd)",
    "opensuse-15": "Opensuse 15",
    "opensuse-tumbleweed": "Opensuse Tumbleweed",
    "oraclelinux-7": "Oracle Linux 7",
    "oraclelinux-8": "Oracle Linux 8",
    "rockylinux-8": "Rocky Linux 8",
    "ubuntu-1804": "Ubuntu 18.04",
    "ubuntu-2004": "Ubuntu 20.04",
    "ubuntu-2204": "Ubuntu 22.04",
    "macos-1015": "macOS 10.15",
    "macos-11": "macOS 11",
    "macos-12": "macOS 12",
    "freebsd-131": "FreeBSD 13.1",
    "freebsd-123": "FreeBSD 12.3",
    "openbsd-6": "OpenBSD 6",
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

    for distro in BSD:
        test_jobs += "\n"
        runs_on = "macos-10.15"
        runs_on = f"\n      runs-on: {runs_on}"
        ifcheck = "\n    if: github.event_name == 'push' || needs.collect-changed-files.outputs.run-tests == 'true'"
        uses = "./.github/workflows/test-bsd.yml"
        instances = []
        timeout_minutes = (
            TIMEOUT_OVERRIDES[distro]
            if distro in TIMEOUT_OVERRIDES
            else TIMEOUT_DEFAULT
        )
        for salt_version in SALT_VERSIONS:

            if salt_version == "latest":
                if distro in LATEST_PKG_BLACKLIST:
                    continue

                instances.append(salt_version)
                continue

            if distro == "openbsd-6":
                # Only test latest on OpenBSD 6
                continue

            if salt_version != "master":
                # Only test the master branch on BSD's
                continue

            # BSD's don't have a stable release, only use git
            for bootstrap_type in ("git",):

                BLACKLIST = {
                    "3003": BLACKLIST_3003,
                    "3004": BLACKLIST_3004,
                }
                if bootstrap_type == "git":
                    BLACKLIST = {
                        "3003": BLACKLIST_GIT_3003,
                        "3004": BLACKLIST_GIT_3004,
                    }

                    # .0 versions are a virtual version for pinning to the first
                    # point release of a major release, such as 3003,
                    # there is no git version.
                    if salt_version.endswith("-0"):
                        continue

                if (
                    salt_version in ("3003", "3004")
                    and distro in BLACKLIST[salt_version]
                ):
                    continue

                kitchen_target = f"{bootstrap_type}-{salt_version}"
                instances.append(kitchen_target)

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
    for distro in OSX:
        test_jobs += "\n"
        if distro == "macos-1015":
            runs_on = "macos-10.15"
        else:
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

            for bootstrap_type in ("stable",):
                if bootstrap_type == "stable":
                    if salt_version == "master":
                        # For the master branch there's no stable build
                        continue

                kitchen_target = f"{bootstrap_type}-{salt_version}"
                instances.append(kitchen_target)

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

            for bootstrap_type in ("stable",):
                if bootstrap_type == "stable":
                    if salt_version == "master":
                        # For the master branch there's no stable build
                        continue

                kitchen_target = f"{bootstrap_type}-{salt_version}"
                instances.append(kitchen_target)

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

            for bootstrap_type in ("stable", "git", "onedir"):
                if bootstrap_type == "onedir":
                    if salt_version not in ONEDIR_SALT_VERSIONS:
                        continue

                if bootstrap_type == "stable":
                    if salt_version == "master":
                        # For the master branch there's no stable build
                        continue
                    if distro not in STABLE_DISTROS:
                        continue

                    if salt_version in STABLE_VERSION_BLACKLIST:
                        continue

                    if distro.startswith("fedora") and salt_version != "latest":
                        # Fedora does not keep old builds around
                        continue

                BLACKLIST = {
                    "3003": BLACKLIST_3003,
                    "3004": BLACKLIST_3004,
                    "3005": BLACKLIST_3005,
                }
                if bootstrap_type == "git":
                    BLACKLIST = {
                        "3003": BLACKLIST_GIT_3003,
                        "3004": BLACKLIST_GIT_3004,
                        "3005": BLACKLIST_GIT_3005,
                    }

                    # .0 versions are a virtual version for pinning to the first
                    # point release of a major release, such as 3003,
                    # there is no git version.
                    if salt_version.endswith("-0"):
                        continue

                if (
                    salt_version in ("3003", "3004", "3005")
                    and distro in BLACKLIST[salt_version]
                ):
                    continue

                kitchen_target = f"{bootstrap_type}-{salt_version}"
                instances.append(kitchen_target)

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
