# -*- coding: utf-8 -*-
"""
    bootstrap.test_usage
    ~~~~~~~~~~~~~~~~~~~~

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the UfSoft.org Team, see AUTHORS for more details.
    :license: BSD, see LICENSE for more details.
"""
from bootstrap import *


class UsageTestCase(BootstrapTestCase):
    def test_no_daemon_install_fails(self):
        '''
        Passing '-N'(no minion) without passing '-M'(install master) or
        '-S'(install syndic) fails.
        '''
        self.assert_script_result(
            'Not installing any daemons did not throw any error',
            1,
            self.run_script(args=('-N',))
        )
