# -*- coding: utf-8 -*-
'''
    bootstrap.test_usage
    ~~~~~~~~~~~~~~~~~~~~

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the UfSoft.org Team, see AUTHORS for more details.
    :license: BSD, see LICENSE for more details.
'''
from bootstrap.unittesting import *


class UsageTestCase(BootstrapTestCase):
    def test_no_daemon_install_shows_warning(self):
        '''
        Passing '-N'(no minion) without passing '-M'(install master) or
        '-S'(install syndic) shows a warning.
        '''
        rc, out, err = self.run_script(
            args=('-N', '-n'),
        )

        self.assert_script_result(
            'Not installing any daemons nor configuring did not throw any '
            'warning',
            0, (rc, out, err)
        )
        self.assertIn(' *  WARN: Nothing to install or configure', out)
