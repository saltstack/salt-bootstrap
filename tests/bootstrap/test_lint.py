# -*- coding: utf-8 -*-
'''
    bootstrap.test_lint
    ~~~~~~~~~~~~~~~~~~~

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the UfSoft.org Team, see AUTHORS for more details.
    :license: BSD, see LICENSE for more details.
'''
from bootstrap.unittesting import *


class LintTestCase(BootstrapTestCase):
    def test_bashisms(self):
        '''
        Lint check the bootstrap script for any possible bash'isms.
        '''
        if not os.path.exists('/usr/bin/perl'):
            self.skipTest('\'/usr/bin/perl\' was not found on this system')
        self.assert_script_result(
            'Some bashisms were found',
            0,
            self.run_script(
                script=os.path.join(EXT_DIR, 'checkbashisms'),
                args=('-pxfn', BOOTSTRAP_SCRIPT_PATH),
                timeout=120,
                stream_stds=True
            )
        )
