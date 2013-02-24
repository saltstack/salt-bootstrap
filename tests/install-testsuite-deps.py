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

import subprocess
from bootstrap import GRAINS

COMMANDS = []
if GRAINS['os'] == 'SmartOS':
    COMMANDS.extend([
        'pkgin -y in scmgit-base py27-pip',
        'pip install unittest2'
    ])

for command in COMMANDS:
    subprocess.Popen(command, shell=True)
