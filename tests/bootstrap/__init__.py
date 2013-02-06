#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
    bootstrap
    ~~~~~~~~~

    salt-bootstrap script unittesting

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the SaltStack Team, see AUTHORS for more details.
    :license: Apache 2.0, see LICENSE for more details.
"""

import os
import sys
import fcntl
import signal
import tempfile
import subprocess
from datetime import datetime, timedelta

# support python < 2.7 via unittest2
if sys.version_info < (2, 7):
    try:
        from unittest2 import (
            TestLoader,
            TextTestRunner,
            TestCase,
            expectedFailure,
            TestSuite,
            skipIf,
        )
    except ImportError:
        raise SystemExit('You need to install unittest2 to run the salt tests')
else:
    from unittest import (
        TestLoader,
        TextTestRunner,
        TestCase,
        expectedFailure,
        TestSuite,
        skipIf,
    )

from bootstrap.ext.os_data import GRAINS

TEST_DIR = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
EXT_DIR = os.path.join(TEST_DIR, 'ext')
PARENT_DIR = os.path.dirname(TEST_DIR)
BOOTSTRAP_SCRIPT_PATH = os.path.join(PARENT_DIR, 'bootstrap-salt-minion.sh')


def non_block_read(output):
    fd = output.fileno()
    fl = fcntl.fcntl(fd, fcntl.F_GETFL)
    fcntl.fcntl(fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    try:
        return output.read()
    except:
        return ''


class BootstrapTestCase(TestCase):
    def run_script(self,
                   script=BOOTSTRAP_SCRIPT_PATH,
                   args=(),
                   cwd=PARENT_DIR,
                   timeout=None,
                   executable='/bin/sh',
                   stream_stds=False):

        cmd = [script] + list(args)

        out = err = ''

        popen_kwargs = {
            'cwd': cwd,
            'shell': True,
            'stderr': subprocess.PIPE,
            'stdout': subprocess.PIPE,
            'close_fds': True,
            'executable': executable,

            # detach from parent group (no more inherited signals!)
            'preexec_fn': os.setpgrp
        }

        cmd = ' '.join(filter(None, [script] + list(args)))

        process = subprocess.Popen(cmd, **popen_kwargs)

        if timeout is not None:
            stop_at = datetime.now() + timedelta(seconds=timeout)
            term_sent = False

        while True:
            process.poll()
            if process.returncode is not None:
                break

            rout = non_block_read(process.stdout)
            if rout:
                out += rout
                if stream_stds:
                    sys.stdout.write(rout)

            rerr = non_block_read(process.stderr)
            if rerr:
                err += rerr
                if stream_stds:
                    sys.stderr.write(rerr)

            if timeout is not None:
                now = datetime.now()

                if now > stop_at:
                    if term_sent is False:
                        # Kill the process group since sending the term signal
                        # would only terminate the shell, not the command
                        # executed in the shell
                        os.killpg(os.getpgid(process.pid), signal.SIGINT)
                        term_sent = True
                        continue

                    # As a last resort, kill the process group
                    os.killpg(os.getpgid(process.pid), signal.SIGKILL)

                    return 1, [
                        'Process took more than {0} seconds to complete. '
                        'Process Killed! Current STDOUT: \n{1}'.format(
                            timeout, out
                        )
                    ], [
                        'Process took more than {0} seconds to complete. '
                        'Process Killed! Current STDERR: \n{1}'.format(
                            timeout, err
                        )
                    ]

        process.communicate()

        try:
            return process.returncode, out.splitlines(), err.splitlines()
        finally:
            try:
                process.terminate()
            except OSError:
                # process already terminated
                pass

    def assert_script_result(self, fail_msg, expected_rc, process_details):
        rc, out, err = process_details
        if rc != expected_rc:
            err_msg = '{0}:\n'.format(fail_msg)
            if out:
                err_msg = '{0}STDOUT:\n{1}\n'.format(err_msg, '\n'.join(out))
            if err:
                err_msg = '{0}STDERR:\n{1}\n'.format(err_msg, '\n'.join(err))
            raise AssertionError(err_msg.rstrip())
