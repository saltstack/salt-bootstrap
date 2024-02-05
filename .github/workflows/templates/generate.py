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
    "centos-7",
    "centos-stream8",
    "centos-stream9",
    "debian-10",
    "debian-11",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "oraclelinux-7",
    "oraclelinux-8",
    "photon-3",
    "photon-4",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2204",
]
WINDOWS = [
    "windows-2019",
    "windows-2022",
]

OSX = [
    "macos-11",
    "macos-12",
]
BSD = [
    "freebsd-131",
    "freebsd-123",
    "openbsd-7",
]

OLD_STABLE_DISTROS = [
    "almalinux-8",
    "amazon-2",
    "arch",
    "centos-7",
    "centos-stream8",
    "debian-10",
    "debian-11",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "oraclelinux-7",
    "oraclelinux-8",
    "rockylinux-8",
    "ubuntu-2004",
]

STABLE_DISTROS = [
    "almalinux-8",
    "almalinux-9",
    "amazon-2",
    "amazon-2023",
    "arch",
    "centos-7",
    "centos-stream8",
    "centos-stream9",
    "debian-10",
    "debian-11",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "opensuse-15",
    "opensuse-tumbleweed",
    "oraclelinux-7",
    "oraclelinux-8",
    "photon-3",
    "photon-4",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2204",
]

ONEDIR_DISTROS = [
    "almalinux-8",
    "almalinux-9",
    "amazon-2",
    "amazon-2023",
    "centos-7",
    "centos-stream8",
    "centos-stream9",
    "debian-10",
    "debian-11",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "oraclelinux-7",
    "oraclelinux-8",
    "photon-3",
    "photon-4",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2204",
]

ONEDIR_RC_DISTROS = [
    "almalinux-8",
    "almalinux-9",
    "amazon-2",
    "centos-7",
    "centos-stream8",
    "centos-stream9",
    "debian-10",
    "debian-11",
    "oraclelinux-7",
    "oraclelinux-8",
    "photon-3",
    "photon-4",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2204",
]

BLACKLIST_3003 = [
    "almalinux-9",
    "amazon-2023",
    "arch",
    "centos-stream9",
    "debian-11",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "photon-3",
    "photon-4",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2204",
]

BLACKLIST_GIT_3003 = [
    "almalinux-9",
    "amazon-2",
    "amazon-2023",
    "arch",
    "centos-stream9",
    "debian-10",
    "debian-11",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "photon-3",
    "photon-4",
    "rockylinux-8",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2110",
    "ubuntu-2204",
]

BLACKLIST_3004 = [
    "almalinux-9",
    "arch",
    "centos-stream9",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "photon-3",
    "photon-4",
    "rockylinux-9",
    "ubuntu-2204",
]

BLACKLIST_3005 = [
    "almalinux-9",
    "arch",
    "centos-stream9",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "photon-3",
    "photon-4",
    "rockylinux-9",
]

BLACKLIST_GIT_3004 = [
    "almalinux-9",
    "amazon-2",
    "amazon-2023",
    "arch",
    "centos-stream9",
    "debian-10",
    "debian-11",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "ubuntu-2004",
    "ubuntu-2110",
    "ubuntu-2204",
    "rockylinux-9",
    "photon-3",
    "photon-4",
    "ubuntu-2204",
]

BLACKLIST_GIT_3005 = [
    "amazon-2",
    "amazon-2023",
    "arch",
    "debian-10",
    "debian-11",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "photon-3",
    "photon-4",
    "ubuntu-2004",
    "ubuntu-2110",
    "ubuntu-2204",
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
    "debian-10",
    "debian-11",
    "debian-12",
    ## DGM "fedora-36",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "photon-3",
    "photon-4",
    "rockylinux-9",
    "ubuntu-2004",
    "ubuntu-2110",
    "ubuntu-2204",
]

BLACKLIST_GIT_MASTER = [
    "amazon-2",
    "debian-10",
    "freebsd-131",
    "freebsd-123",
    "photon-3",
]

SALT_VERSIONS = [
    "3003",
    "3004",
    "3005",
    "3005-1",
    "3006",
    "3006-1",
    "master",
    "latest",
    "nightly",
]

ONEDIR_SALT_VERSIONS = [
    "3005",
    "3006",
    "latest",
]

ONEDIR_RC_SALT_VERSIONS = []

VERSION_DISPLAY_NAMES = {
    "3003": "v3003",
    "3004": "v3004",
    "3005": "v3005",
    "3005-1": "v3005.1",
    "3006": "v3006",
    "3006-1": "v3006.1",
    "3006-6": "v3006.6",
    "master": "Master",
    "latest": "Latest",
    "nightly": "Nightly",
}

OLD_STABLE_VERSION_BLACKLIST = [
    "3005-1",
    "3006",
    "3006-1",
    "master",
    "nightly",
]

STABLE_VERSION_BLACKLIST = [
    "3003",
    "3004",
    "master",
    "nightly",
]

MAC_OLD_STABLE_VERSION_BLACKLIST = [
    "3005-1",
    "3006",
    "3006-1",
    "3006-6",
    "master",
    "nightly",
]

MAC_STABLE_VERSION_BLACKLIST = [
    "3003",
    "3004",
    "3005",
    "3005-1",
    "master",
    "nightly",
]

GIT_VERSION_BLACKLIST = [
    "3005-1",
    "3006-1",
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
    "centos-7",
    "centos-stream8",
    "fedora-37",
    "fedora-38",
    "fedora-39",
    "opensuse-15",
    "oraclelinux-7",
    "oraclelinux-8",
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
    "centos-7": "CentOS 7",
    "centos-stream8": "CentOS Stream 8",
    "centos-stream9": "CentOS Stream 9",
    "debian-10": "Debian 10",
    "debian-11": "Debian 11",
    "debian-12": "Debian 12",
    ## DGM "fedora-36": "Fedora 36",
    "fedora-37": "Fedora 37",
    "fedora-38": "Fedora 38",
    "fedora-39": "Fedora 39",
    "gentoo": "Gentoo",
    "gentoo-systemd": "Gentoo (systemd)",
    "opensuse-15": "Opensuse 15",
    "opensuse-tumbleweed": "Opensuse Tumbleweed",
    "oraclelinux-7": "Oracle Linux 7",
    "oraclelinux-8": "Oracle Linux 8",
    "photon-3": "Photon OS 3",
    "photon-4": "Photon OS 4",
    "rockylinux-8": "Rocky Linux 8",
    "rockylinux-9": "Rocky Linux 9",
    "ubuntu-2004": "Ubuntu 20.04",
    "ubuntu-2204": "Ubuntu 22.04",
    "macos-1015": "macOS 10.15",
    "macos-11": "macOS 11",
    "macos-12": "macOS 12",
    "freebsd-131": "FreeBSD 13.1",
    "freebsd-123": "FreeBSD 12.3",
    "openbsd-7": "OpenBSD 7",
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
        runs_on = "macos-12"
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

            if distro == "openbsd-7":
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
                        "master": BLACKLIST_GIT_MASTER,
                    }

                    # .0 versions are a virtual version for pinning to the first
                    # point release of a major release, such as 3003,
                    # there is no git version.
                    if salt_version.endswith("-0"):
                        continue

                if (
                    salt_version in ("3003", "3004", "master")
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

            for bootstrap_type in ("stable", "old-stable"):
                if bootstrap_type == "stable":
                    if salt_version in MAC_STABLE_VERSION_BLACKLIST:
                        continue

                if bootstrap_type == "old-stable":
                    if salt_version in MAC_OLD_STABLE_VERSION_BLACKLIST:
                        continue

                kitchen_target = f"{bootstrap_type}-{salt_version}"
                instances.append(kitchen_target)

        for bootstrap_type in ("default",):
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

            for bootstrap_type in ("stable",):
                if bootstrap_type == "stable":
                    if salt_version in STABLE_VERSION_BLACKLIST:
                        continue

                kitchen_target = f"{bootstrap_type}-{salt_version}"
                instances.append(kitchen_target)

        for bootstrap_type in ("default",):
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
                "old-stable",
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

                if bootstrap_type == "old-stable":
                    if salt_version in OLD_STABLE_VERSION_BLACKLIST:
                        continue
                    if distro not in OLD_STABLE_DISTROS:
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
                    "3003": BLACKLIST_3003,
                    "3004": BLACKLIST_3004,
                    "3005": BLACKLIST_3005,
                    "3005-1": BLACKLIST_3005,
                    "3006": BLACKLIST_3006,
                    "3006-1": BLACKLIST_3006,
                }
                if bootstrap_type == "git":
                    BLACKLIST = {
                        "3003": BLACKLIST_GIT_3003,
                        "3004": BLACKLIST_GIT_3004,
                        "3005": BLACKLIST_GIT_3005,
                        "3006": BLACKLIST_GIT_3006,
                        "master": BLACKLIST_GIT_MASTER,
                    }

                    # .0 versions are a virtual version for pinning to the first
                    # point release of a major release, such as 3003,
                    # there is no git version.
                    if salt_version.endswith("-0"):
                        continue

                if (
                    salt_version
                    in ("3003", "3004", "3005", "3005-1", "3006", "3006-1", "master")
                    and distro in BLACKLIST[salt_version]
                ):
                    continue

                kitchen_target = f"{bootstrap_type}-{salt_version}"
                instances.append(kitchen_target)

        for bootstrap_type in ("default",):
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
