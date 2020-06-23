#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os
import datetime

os.chdir(os.path.abspath(os.path.dirname(__file__)))

LINUX_DISTROS = [
#    'amazon-1',
    'amazon-2',
    'arch',
    'centos-6',
    'centos-7',
    'centos-8',
    'debian-10',
    'debian-8',
    'debian-9',
    'fedora-30',
    'fedora-31',
    'fedora-32',
    'opensuse-15',
    'ubuntu-1604',
    'ubuntu-1804',
    'ubuntu-2004',
]
OSX = WINDOWS = []

STABLE_DISTROS = [
    'amazon-1',
    'amazon-2',
    'centos-6',
    'centos-7',
    'centos-8',
    'debian-10',
    'debian-8',
    'debian-9',
    'fedora-30',
    'fedora-31',
    'fedora-32',
    'ubuntu-1604',
    'ubuntu-1804',
    'ubuntu-2004',
]

PY2_BLACKLIST = [
    'centos-8',
    'debian-10',
    'fedora-30',
    'fedora-31',
    'fedora-32',
    'opensuse-15',
    'ubuntu-2004',
]

PY3_BLACKLIST = [
    'amazon-1',
    'centos-6',
    'debian-8',
]

BLACKLIST_2019 = [
    'ubuntu-2004',
]

BLACKLIST_3000 = [
    'ubuntu-2004',
]

SALT_BRANCHES = [
    '2019-2',
    '3000',
    '3001',
    'master',
    'latest'
]

SALT_POST_3000_BLACKLIST = [
    'centos-6',
    'debian-8',
    'fedora-30',
]

BRANCH_DISPLAY_NAMES = {
    '2019-2': 'v2019.2',
    '3000': 'v3000',
    '3001': 'v3001',
    'master': 'Master',
    'latest': 'Latest'
}

STABLE_BRANCH_BLACKLIST = [
]

LATEST_PKG_BLACKLIST = [
    'arch',         # No packages are built
]

DISTRO_DISPLAY_NAMES = {
    'amazon-1': 'Amazon 1',
    'amazon-2': 'Amazon 2',
    'arch': 'Arch',
    'centos-6': 'CentOS 6',
    'centos-7': 'CentOS 7',
    'centos-8': 'CentOS 8',
    'debian-10': 'Debian 10',
    'debian-8': 'Debian 8',
    'debian-9': 'Debian 9',
    'fedora-30': 'Fedora 30',
    'fedora-31': 'Fedora 31',
    'fedora-32': 'Fedora 32',
    'opensuse-15': 'Opensuse 15',
    'ubuntu-1604': 'Ubuntu 16.04',
    'ubuntu-1804': 'Ubuntu 18.04',
    'ubuntu-2004': 'Ubuntu 20.04',
}


def generate_test_jobs():
    test_jobs = ''

    for distro in LINUX_DISTROS + OSX + WINDOWS:
        for branch in SALT_BRANCHES:

            if branch == 'master' and distro in SALT_POST_3000_BLACKLIST:
                continue
            try:
                if int(branch) >= 3000 and distro in SALT_POST_3000_BLACKLIST:
                    continue
            except ValueError:
                pass

            if branch == 'latest':
                if distro in LATEST_PKG_BLACKLIST:
                    continue
                if distro in LINUX_DISTROS:
                    template = 'linux.yml'
                elif distro in OSX:
                    template = 'osx.yml'
                elif distro in WINDOWS:
                    template = 'windows.yml'
                else:
                    print("Don't know how to handle {}".format(distro))

                with open(template) as rfh:
                    test_jobs += '\n{}\n'.format(
                        rfh.read().replace(
                            '{python_version}-{bootstrap_type}-{branch}-{distro}',
                            '{branch}-{distro}'
                        ).format(
                            distro=distro,
                            branch=branch,
                            display_name='{} Latest packaged release'.format(
                                DISTRO_DISPLAY_NAMES[distro],
                            )
                        )
                    )
                continue

            for python_version in ('py2', 'py3'):

                if branch == 'master' and python_version == 'py2':
                    # Salt's master branch no longer supports Python 2
                    continue

                try:
                    if int(branch) >= 3000 and python_version == 'py2':
                        # Salt's 300X versions no longer supports Python 2
                        continue
                except ValueError:
                    pass

                for bootstrap_type in ('stable', 'git'):
                    if bootstrap_type == 'stable':
                        if branch == 'master':
                            # For the master branch there's no stable build
                            continue
                        if distro not in STABLE_DISTROS:
                            continue

                        if branch in STABLE_BRANCH_BLACKLIST:
                            continue

                        if distro.startswith("fedora") and branch != "latest":
                            # Fedora does not keep old builds around
                            continue

                    if bootstrap_type == "git":
                        if python_version == "py3":
                            if distro in ("arch", "fedora-32"):
                                allowed_branches = ["master"]
                                try:
                                    int_branch = int(branch)
                                    if int_branch > 3000:
                                        allowed_branches.append(branch)
                                except ValueError:
                                    pass
                                if branch not in allowed_branches:
                                    # Arch and Fedora default to py3.8
                                    continue
                    if branch == '2019-2' and distro in BLACKLIST_2019:
                        continue

                    if branch == '3000' and distro in BLACKLIST_3000:
                        continue

                    if python_version == 'py2' and distro in PY2_BLACKLIST:
                        continue

                    if python_version == 'py3' and distro in PY3_BLACKLIST:
                        continue

                    if distro in LINUX_DISTROS:
                        template = 'linux.yml'
                    elif distro in OSX:
                        template = 'osx.yml'
                    elif distro in WINDOWS:
                        template = 'windows.yml'
                    else:
                        print("Don't know how to handle {}".format(distro))

                    with open(template) as rfh:
                        test_jobs += '\n{}\n'.format(
                            rfh.read().format(
                                distro=distro,
                                branch=branch,
                                python_version=python_version,
                                bootstrap_type=bootstrap_type,
                                display_name='{} {} {} {}'.format(
                                    DISTRO_DISPLAY_NAMES[distro],
                                    BRANCH_DISPLAY_NAMES[branch],
                                    python_version.capitalize(),
                                    bootstrap_type.capitalize()
                                )
                            )
                        )

    with open('lint.yml') as rfh:
        lint_job = '\n{}\n'.format(rfh.read())

    with open('pre-commit.yml') as rfh:
        pre_commit_job = '\n{}\n'.format(rfh.read())

    with open('../main.yml', 'w') as wfh:
        with open('main.yml') as rfh:
            wfh.write(
                '{}\n'.format(
                    rfh.read().format(
                        jobs='{pre_commit}{lint}{test}'.format(
                            lint=lint_job,
                            test=test_jobs,
                            pre_commit=pre_commit_job,
                        )
                    ).strip()
                )
            )


if __name__ == '__main__':
    generate_test_jobs()
