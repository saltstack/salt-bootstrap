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


TEST_DIR = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
EXT_DIR = os.path.join(TEST_DIR, 'ext')
PARENT_DIR = os.path.dirname(TEST_DIR)
BOOTSTRAP_SCRIPT_PATH = os.path.join(PARENT_DIR, 'bootstrap-salt-minion.sh')


class Tee(object):
    def __init__(self, realstd=None):
        fd_, self.filename = tempfile.mkstemp()
        os.close(fd_)
        self.logfile = open(self.filename, 'w')
        if realstd is not None:
            realstd.write('\n')
            realstd.flush()
            # Duplicate what's written to the filename to the realstd
            os.dup2(realstd.fileno(), self.fileno())

    def __del__(self):
        if not self.logfile.closed:
            self.logfile.close()
        os.unlink(self.filename)

    def close(self):
        if not self.logfile.closed:
            self.logfile.close()

    def fileno(self):
        return self.logfile.fileno()

    def write(self, data):
        if not self.logfile.closed:
            self.logfile.write(data)

    def flush(self):
        self.logfile.flush()

    def read(self):
        return open(self.filename, 'r').read()

    def splitlines(self):
        return self.read().splitlines()

    # StringIO methods
    def getvalue(self):
        return self.read()


class BootstrapTestCase(TestCase):
    def run_script(self,
                   script=BOOTSTRAP_SCRIPT_PATH,
                   args=(),
                   cwd=PARENT_DIR,
                   timeout=None,
                   executable='/bin/sh',
                   stream_stds=False):

        cmd = [script] + list(args)

        if stream_stds:
            stderr = Tee(sys.stderr)
            stdout = Tee(sys.stdout)
        else:
            stderr = Tee()
            stdout = Tee()

        popen_kwargs = {
            'cwd': cwd,
            'shell': True,
            #'stderr': subprocess.PIPE,
            #'stdout': subprocess.PIPE,
            'stderr': stderr,
            'stdout': stdout,
            'close_fds': True,
            'executable': executable,

            # detach from parent group (no more inherited signals!)
            'preexec_fn': os.setpgrp
        }

        cmd = ' '.join([script] + list(args))

        process = subprocess.Popen(cmd, **popen_kwargs)

        if timeout is not None:
            ping_at = datetime.now() + timedelta(seconds=5)
            stop_at = datetime.now() + timedelta(seconds=timeout)
            term_sent = False
            while True:
                process.poll()
                if process.returncode is not None:
                    break

                now = datetime.now()
                if now > ping_at:
                    #sys.stderr.write('.')
                    #sys.stderr.flush()
                    ping_at = datetime.now() + timedelta(seconds=5)

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
                        'Process Killed!'.format(timeout)
                    ], ['Process killed, unable to catch stderr output']

        #if sys.version_info < (2, 7):
            # On python 2.6, the subprocess'es communicate() method uses
            # select which, is limited by the OS to 1024 file descriptors
            # We need more available descriptors to run the tests which
            # need the stderr output.
            # So instead of .communicate() we wait for the process to
            # finish, but, as the python docs state "This will deadlock
            # when using stdout=PIPE and/or stderr=PIPE and the child
            # process generates enough output to a pipe such that it
            # blocks waiting for the OS pipe buffer to accept more data.
            # Use communicate() to avoid that." <- a catch, catch situation
            #
            # Use this work around were it's needed only, python 2.6
        #    process.wait()
        #    out = process.stdout.read()
        #    err = process.stderr.read()
        #else:
        out, err = process.communicate()
        # Force closing stderr/stdout to release file descriptors
        stdout.close()
        stderr.close()
        try:
            return process.returncode, stdout.splitlines(), stderr.splitlines()
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
