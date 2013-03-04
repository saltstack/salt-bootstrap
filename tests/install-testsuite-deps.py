#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''
    install-testsuite-deps.py
    ~~~~~~~~~~~~~~~~~~~~~~~~~

    Install the required dependencies to properly run the test-suite.

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the SaltStack Team, see AUTHORS for more details.
    :license: Apache 2.0, see LICENSE for more details.
'''

# Import python libs
import re
import sys
import pprint
import subprocess

# Import bootstrap libs
from bootstrap.ext.os_data import GRAINS


COMMANDS = []
if GRAINS['os'] == 'SmartOS':
    COMMANDS.extend([
        'pkgin up',
        'pkgin -y in scmgit-base py27-pip',
        'pip install unittest2'
    ])
elif GRAINS['os'] == 'openSUSE':
    COMMANDS.extend([
        'zypper --non-interactive addrepo --refresh http://download.opensuse.org/repositories'
        '/devel:/languages:/python/{0}/devel:languages:python.repo'.format(
            GRAINS['osrelease']
        ),
        'zypper --gpg-auto-import-keys --non-interactive refresh',
        'zypper --non-interactive install --auto-agree-with-licenses git python-pip',
        'pip install unittest2'
    ])
elif GRAINS['osfullname'].startswith('SUSE Linux Enterprise Server'):
    match = re.search(
        r'PATCHLEVEL(?:[\s]+)=(?:[\s]+)([0-9]+)',
        open('/etc/SuSE-release').read()
    )
    #if not match:
    #    print 'Failed to get the current patch level for:\n{0}'.format(
    #        pprint.pformat(GRAINS)
    #    )
    COMMANDS.extend([
        'zypper --non-interactive addrepo --refresh http://download.opensuse.org/repositories'
        '/devel:/languages:/python/SLE_{0}{1}/devel:languages:python.repo'.format(
            GRAINS['osrelease'],
            match and '_SP{0}'.format(match.group(1)) or ''
        ),
        'zypper --gpg-auto-import-keys --non-interactive refresh',
        'zypper --non-interactive install --auto-agree-with-licenses git python-pip',
        'pip install unittest2'
    ])
elif GRAINS['os'] == 'Amazon':
    COMMANDS.extend([
        'rpm -Uvh --force http://mirrors.kernel.org/fedora-epel/6/'
        '{0}/epel-release-6-8.noarch.rpm'.format(
            GRAINS['cpuarch'] == 'i686' and 'i386' or GRAINS['cpuarch']
        ),
        'yum -y update',
        'yum -y install python-pip --enablerepo=epel-testing',
        'pip-python install unittest2'
    ])
elif GRAINS['os'] == 'Fedora':
    COMMANDS.extend([
        'yum -y update',
        'yum -y install python-pip',
        'pip-python install unittest2'
    ])
elif GRAINS['os_family'] == 'Debian':
    COMMANDS.extend([
        'apt-get update',
        'apt-get install -y -o DPkg::Options::=--force-confold '
        '-o Dpkg::Options::="--force-confdef" python-pip',
        'pip install unittest2'
    ])
else:
    print(
        'Failed gather the proper commands to allow the tests suite to be '
        'executed in this system.\nSystem Grains:\n{0}'.format(
            pprint.pformat(GRAINS)
        )
    )
    sys.exit(1)


for command in COMMANDS:
    print 'Executing {0!r}'.format(command)
    process = subprocess.Popen(command, shell=True)
    process.communicate()

print('\nDONE\n')
exit(0)
