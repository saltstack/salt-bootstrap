# -*- coding: utf-8 -*-
'''
    bootstrap.unittesting
    ~~~~~~~~~~~~~~~~~~~~~

    Unit testing related classes, helpers.

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the SaltStack Team, see AUTHORS for more details.
    :license: Apache 2.0, see LICENSE for more details.
'''

# Import python libs
import os
import sys
import fcntl
import signal
import logging
import subprocess
from datetime import datetime, timedelta

# Import salt testing libs
from salttesting import *
from salttesting.ext.os_data import GRAINS

TEST_DIR = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
EXT_DIR = os.path.join(TEST_DIR, 'ext')
PARENT_DIR = os.path.dirname(TEST_DIR)
BOOTSTRAP_SCRIPT_PATH = os.path.join(PARENT_DIR, 'bootstrap-salt.sh')


class NonBlockingPopen(subprocess.Popen):

    _stdout_logger_name_ = 'salt-bootstrap.NonBlockingPopen.STDOUT.PID-{pid}'
    _stderr_logger_name_ = 'salt-bootstrap.NonBlockingPopen.STDERR.PID-{pid}'

    def __init__(self, *args, **kwargs):
        self.stream_stds = kwargs.pop('stream_stds', False)
        self._stdout_logger = self._stderr_logger = None
        super(NonBlockingPopen, self).__init__(*args, **kwargs)
        if self.stdout is not None and self.stream_stds:
            fod = self.stdout.fileno()
            fol = fcntl.fcntl(fod, fcntl.F_GETFL)
            fcntl.fcntl(fod, fcntl.F_SETFL, fol | os.O_NONBLOCK)
            self.obuff = ''

        if self.stderr is not None and self.stream_stds:
            fed = self.stderr.fileno()
            fel = fcntl.fcntl(fed, fcntl.F_GETFL)
            fcntl.fcntl(fed, fcntl.F_SETFL, fel | os.O_NONBLOCK)
            self.ebuff = ''

    def poll(self):
        if self._stdout_logger is None:
            self._stdout_logger = logging.getLogger(
                self._stdout_logger_name_.format(pid=self.pid)
            )
        if self._stderr_logger is None:
            self._stderr_logger = logging.getLogger(
                self._stderr_logger_name_.format(pid=self.pid)
            )
        poll = super(NonBlockingPopen, self).poll()

        if self.stdout is not None and self.stream_stds:
            try:
                obuff = self.stdout.read()
                self.obuff += obuff
                if obuff.strip():
                    self._stdout_logger.info(obuff.strip())
                sys.stdout.write(obuff)
            except IOError, err:
                if err.errno not in (11, 35):
                    # We only handle Resource not ready properly, any other
                    # raise the exception
                    raise
        if self.stderr is not None and self.stream_stds:
            try:
                ebuff = self.stderr.read()
                self.ebuff += ebuff
                if ebuff.strip():
                    self._stderr_logger.info(ebuff.strip())
                sys.stderr.write(ebuff)
            except IOError, err:
                if err.errno not in (11, 35):
                    # We only handle Resource not ready properly, any other
                    # raise the exception
                    raise

        if poll is None:
            # Not done yet
            return poll

        if not self.stream_stds:
            # Allow the same attribute access even though not streaming to stds
            try:
                self.obuff = self.stdout.read()
            except IOError, err:
                if err.errno not in (11, 35):
                    # We only handle Resource not ready properly, any other
                    # raise the exception
                    raise
            try:
                self.ebuff = self.stderr.read()
            except IOError, err:
                if err.errno not in (11, 35):
                    # We only handle Resource not ready properly, any other
                    # raise the exception
                    raise
        return poll


class BootstrapTestCase(TestCase):
    def run_script(self,
                   script=BOOTSTRAP_SCRIPT_PATH,
                   args=(),
                   cwd=PARENT_DIR,
                   timeout=None,
                   executable='/bin/sh',
                   stream_stds=False):

        cmd = [script] + list(args)

        popen_kwargs = {
            'cwd': cwd,
            'shell': True,
            'stderr': subprocess.PIPE,
            'stdout': subprocess.PIPE,
            'close_fds': True,
            'executable': executable,

            'stream_stds': stream_stds,

            # detach from parent group (no more inherited signals!)
            #'preexec_fn': os.setpgrp
        }

        cmd = ' '.join(filter(None, [script] + list(args)))

        process = NonBlockingPopen(cmd, **popen_kwargs)

        if timeout is not None:
            stop_at = datetime.now() + timedelta(seconds=timeout)
            term_sent = False

        while process.poll() is None:

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
                            timeout, process.obuff
                        )
                    ], [
                        'Process took more than {0} seconds to complete. '
                        'Process Killed! Current STDERR: \n{1}'.format(
                            timeout, process.ebuff
                        )
                    ]

        process.communicate()

        try:
            return (
                process.returncode,
                process.obuff.splitlines(),
                process.ebuff.splitlines()
            )
        finally:
            try:
                process.terminate()
            except OSError:
                # process already terminated
                pass

    def assert_script_result(self, fail_msg, expected_rcs, process_details):
        if not isinstance(expected_rcs, (tuple, list)):
            expected_rcs = (expected_rcs,)

        rc, out, err = process_details
        if rc not in expected_rcs:
            err_msg = '{0}:\n'.format(fail_msg)
            if out:
                err_msg = '{0}STDOUT:\n{1}\n'.format(err_msg, '\n'.join(out))
            if err:
                err_msg = '{0}STDERR:\n{1}\n'.format(err_msg, '\n'.join(err))
            if not err and not out:
                err_msg = (
                    '{0} No stdout nor stderr captured. Exit code: {1}'.format(
                        err_msg, rc
                    )
                )
            raise AssertionError(err_msg.rstrip())
