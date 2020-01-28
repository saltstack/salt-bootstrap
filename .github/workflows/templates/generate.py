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
    #'fedora-31',
    'opensuse-15',
    'ubuntu-1604',
    'ubuntu-1804'
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
    'ubuntu-1604',
    'ubuntu-1804',
]

PY2_BLACKLIST = [
    'centos-8',
    'debian-10',
    'fedora-31',
]

PY3_BLACKLIST = [
    'amazon-1',
    'centos-6',
    'debian-8',
    'opensuse-15'
]

BLACKLIST_2018 = [
    'amazon-2',
    'centos-8',
    'debian-10',
]

SALT_BRANCHES = [
    '2018-3',
    '2019-2',
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
    'opensuse-15': 'Opensuse 15',
    'ubuntu-1604': 'Ubuntu 16.04',
    'ubuntu-1804': 'Ubuntu 18.04'
}


def generate_test_jobs():
    test_jobs = ''

    for distro in LINUX_DISTROS + OSX + WINDOWS:
        for branch in SALT_BRANCHES:
            for python_version in ('py2', 'py3'):
                for bootstrap_type in ('stable', 'git'):
                    if bootstrap_type == 'stable' and distro not in STABLE_DISTROS:
                        continue

                    if branch == '2018-3' and distro in BLACKLIST_2018:
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
                                    branch.replace('-', '.'),
                                    python_version.capitalize(),
                                    bootstrap_type.capitalize()
                                )
                            )
                        )


    with open('lint.yml') as rfh:
        lint_job = '\n{}\n'.format(rfh.read())

    with open('../main.yml', 'w') as wfh:
        with open('main.yml') as rfh:
            wfh.write(
                rfh.read().format(
                    lint_job=lint_job,
                    test_jobs=test_jobs,
                )
            )


if __name__ == '__main__':
    generate_test_jobs()
