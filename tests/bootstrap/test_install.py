# -*- coding: utf-8 -*-
'''
    bootstrap.test_install
    ~~~~~~~~~~~~~~~~~~~~~~

    Run installation tests.

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the SaltStack Team, see AUTHORS for more details.
    :license: Apache 2.0, see LICENSE for more details.
'''

from bootstrap import *


class InstallationTestCase(BootstrapTestCase):

    def setUp(self):
        if os.geteuid() is not 0:
            self.skipTest('you must be root to run this test')

    def test_install_using_bash(self):
        if not os.path.exists('/bin/bash'):
            self.skipTest('\'/bin/bash\' was not found on this system')

        self.assert_script_result(
            'Failed to install using bash',
            0,
            self.run_script(
                executable='/bin/bash',
                timeout=15*60,
                stream_stds=True
            )
        )

    def test_install_using_sh(self):
        self.assert_script_result(
            'Failed to install using sh',
            0,
            self.run_script(
                timeout=15*60,
                stream_stds=True
            )
        )

    def test_install_daily(self):
        rc, out, err = self.run_script(
            args=('daily',), timeout=15*60, stream_stds=True
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
