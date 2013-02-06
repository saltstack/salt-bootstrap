# -*- coding: utf-8 -*-
'''
    bootstrap.test_install
    ~~~~~~~~~~~~~~~~~~~~~~

    Run installation tests.

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the SaltStack Team, see AUTHORS for more details.
    :license: Apache 2.0, see LICENSE for more details.
'''

import shutil
from bootstrap import *


class InstallationTestCase(BootstrapTestCase):

    def setUp(self):
        if os.geteuid() is not 0:
            self.skipTest('you must be root to run this test')

    def tearDown(self):
        cleanup_commands = []
        if GRAINS['os_family'] == 'Debian':
            cleanup_commands.append(
                'apt-get remove -y -o DPkg::Options::=--force-confold '
                '--purge salt-master salt-minion salt-syndic'
            )
            cleanup_commands.append(
                'apt-get autoremove -y -o DPkg::Options::=--force-confold '
                '--purge'
            )
        elif GRAINS['os_family'] == 'RedHat':
            cleanup_commands.append(
                'yum -y remove salt-minion salt-master'
            )

        for cleanup in cleanup_commands:
            print 'Running cleanup command {0!r}'.format(cleanup)
            self.assert_script_result(
                'Failed to execute cleanup command {0!r}'.format(cleanup),
                0,
                self.run_script(
                    args=cleanup.split(),
                    timeout=15 * 60,
                    stream_stds=True
                )
            )

        if os.path.isdir('/tmp/git'):
            print 'Cleaning salt git checkout'
            shutil.rmtree('/tmp/git')

    def test_install_using_bash(self):
        if not os.path.exists('/bin/bash'):
            self.skipTest('\'/bin/bash\' was not found on this system')

        self.assert_script_result(
            'Failed to install using bash',
            0,
            self.run_script(
                executable='/bin/bash',
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_install_using_sh(self):
        self.assert_script_result(
            'Failed to install using sh',
            0,
            self.run_script(
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_install_explicit_stable(self):
        self.assert_script_result(
            'Failed to install explicit stable using sh',
            0,
            self.run_script(
                args=('stable'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_install_daily(self):
        rc, out, err = self.run_script(
            args=('daily',), timeout=15 * 60, stream_stds=True
        )
        if GRAINS['os'] == 'Ubuntu':
            self.assert_script_result(
                'Failed to install daily',
                0, (rc, out, err)
            )
        else:
            self.assert_script_result(
                'Although system is not Ubuntu, we managed to install',
                1, (rc, out, err)
            )

    def test_install_stable_piped_through_sh(self):
        self.assert_script_result(
            'Failed to install stable piped through sh',
            0,
            self.run_script(
                args='cat {0} | sh '.format(BOOTSTRAP_SCRIPT_PATH).split(),
                timeout=15 * 60,
                stream_stds=True
            )
        )

