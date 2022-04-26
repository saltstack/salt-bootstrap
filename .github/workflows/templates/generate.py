#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os
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
    "debian-9",
    "fedora-34",
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
    "ubuntu-2110",
    "ubuntu-2204",
]
OSX = WINDOWS = []

STABLE_DISTROS = [
    "almalinux-8",
    "amazon-2",
    "arch",
    "centos-7",
    "centos-stream8",
    "debian-10",
    "debian-11",
    "debian-9",
    "fedora-34",
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
    "ubuntu-2110",
    "ubuntu-2204",
]

BLACKLIST_3002 = [
    "almalinux-8",
    "arch",
    "centos-stream8",
    "debian-11",
    "fedora-34",
    "fedora-35",
    "fedora-36",
    "gentoo",
    "gentoo-systemd",
    "opensuse-15",
    "opensuse-tumbleweed",
    "rockylinux-8",
    "ubuntu-2204",
]

BLACKLIST_GIT_3002 = [
    "almalinux-8",
    "amazon-2",
    "arch",
    "centos-stream8",
    "debian-10",
    "debian-11",
    "fedora-34",
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

BLACKLIST_3003 = [
    "arch",
    "debian-11",
    "fedora-34",
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
    "fedora-34",
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
    "fedora-34",
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
    "fedora-34",
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

SALT_BRANCHES = [
    "3002",
    "3003",
    "3004",
    "master",
    "latest",
]

BRANCH_DISPLAY_NAMES = {
    "3002": "v3002",
    "3003": "v3003",
    "3004": "v3004",
    "master": "Master",
    "latest": "Latest",
}

STABLE_BRANCH_BLACKLIST = []

LATEST_PKG_BLACKLIST = []

DISTRO_DISPLAY_NAMES = {
    "almalinux-8": "AlmaLinux 8",
    "amazon-2": "Amazon 2",
    "arch": "Arch",
    "centos-7": "CentOS 7",
    "centos-stream8": "CentOS Stream 8",
    "debian-10": "Debian 10",
    "debian-11": "Debian 11",
    "debian-9": "Debian 9",
    "fedora-34": "Fedora 34",
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
    "ubuntu-2110": "Ubuntu 21.10",
    "ubuntu-2204": "Ubuntu 22.04",
}

TIMEOUT_DEFAULT = 20
TIMEOUT_OVERRIDES = {
    "gentoo": 90,
    "gentoo-systemd": 90,
}
BRANCH_ONLY_OVERRIDES = [
    "gentoo",
    "gentoo-systemd",
]


def generate_test_jobs():
    test_jobs = ""
    branch_only_test_jobs = ""

    for distro in LINUX_DISTROS + OSX + WINDOWS:
        timeout_minutes = (
            TIMEOUT_OVERRIDES[distro]
            if distro in TIMEOUT_OVERRIDES
            else TIMEOUT_DEFAULT
        )
        needs = "    needs: lint"
        if distro in BRANCH_ONLY_OVERRIDES:
            needs = ""
        current_test_jobs = ""

        for branch in SALT_BRANCHES:

            if branch == "latest":
                if distro in LATEST_PKG_BLACKLIST:
                    continue
                if distro in LINUX_DISTROS:
                    template = "linux.yml"
                elif distro in OSX:
                    template = "osx.yml"
                elif distro in WINDOWS:
                    template = "windows.yml"
                else:
                    print("Don't know how to handle {}".format(distro))

                with open(template) as rfh:
                    current_test_jobs += "\n{}\n".format(
                        rfh.read()
                        .replace(
                            "{python_version}-{bootstrap_type}-{branch}-{distro}",
                            "{branch}-{distro}",
                        )
                        .format(
                            distro=distro,
                            branch=branch,
                            display_name="{} Latest packaged release".format(
                                DISTRO_DISPLAY_NAMES[distro],
                            ),
                            timeout_minutes=timeout_minutes,
                            needs=needs,
                        )
                    )
                continue

            for python_version in ("py3",):

                for bootstrap_type in ("stable", "git"):
                    if bootstrap_type == "stable":
                        if branch == "master":
                            # For the master branch there's no stable build
                            continue
                        if distro not in STABLE_DISTROS:
                            continue

                        if branch in STABLE_BRANCH_BLACKLIST:
                            continue

                        if distro.startswith("fedora") and branch != "latest":
                            # Fedora does not keep old builds around
                            continue

                    BLACKLIST = {
                        "3002": BLACKLIST_3002,
                        "3003": BLACKLIST_3003,
                        "3004": BLACKLIST_3004,
                    }
                    if bootstrap_type == "git":
                        BLACKLIST = {
                            "3002": BLACKLIST_GIT_3002,
                            "3003": BLACKLIST_GIT_3003,
                            "3004": BLACKLIST_GIT_3004,
                        }

                        # .0 versions are a virtual version for pinning to the first point release of a major release, such as 3002, there is no git version.
                        if branch.endswith("-0"):
                            continue

                    if (
                        branch in ("3002", "3003", "3004")
                        and distro in BLACKLIST[branch]
                    ):
                        continue

                    if distro in LINUX_DISTROS:
                        template = "linux.yml"
                    elif distro in OSX:
                        template = "osx.yml"
                    elif distro in WINDOWS:
                        template = "windows.yml"
                    else:
                        print("Don't know how to handle {}".format(distro))

                    with open(template) as rfh:
                        current_test_jobs += "\n{}\n".format(
                            rfh.read().format(
                                distro=distro,
                                branch=branch,
                                python_version=python_version,
                                bootstrap_type=bootstrap_type,
                                display_name="{} {} {} {}".format(
                                    DISTRO_DISPLAY_NAMES[distro],
                                    BRANCH_DISPLAY_NAMES[branch],
                                    python_version.capitalize(),
                                    bootstrap_type.capitalize(),
                                ),
                                timeout_minutes=timeout_minutes,
                                needs=needs,
                            )
                        )
        if distro in BRANCH_ONLY_OVERRIDES:
            branch_only_test_jobs += current_test_jobs
        else:
            test_jobs += current_test_jobs

    with open("lint.yml") as rfh:
        lint_job = "\n{}\n".format(rfh.read())

    with open("pre-commit.yml") as rfh:
        pre_commit_job = "\n{}\n".format(rfh.read())

    with open("../main.yml", "w") as wfh:
        with open("main.yml") as rfh:
            wfh.write(
                "{}\n".format(
                    rfh.read()
                    .format(
                        jobs="{pre_commit}{lint}{test}".format(
                            lint=lint_job,
                            test=test_jobs,
                            pre_commit=pre_commit_job,
                        ),
                        on="push, pull_request",
                        name="Testing",
                    )
                    .strip()
                )
            )

    with open("../main-branch-only.yml", "w") as wfh:
        with open("main.yml") as rfh:
            wfh.write(
                "{}\n".format(
                    rfh.read()
                    .format(
                        jobs="{test}".format(
                            test=branch_only_test_jobs,
                        ),
                        on="push",
                        name="Branch Testing",
                    )
                    .strip()
                )
            )


if __name__ == "__main__":
    generate_test_jobs()
