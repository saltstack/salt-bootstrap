# -*- coding: utf-8 -*-
'''
    bootstrap.test_install
    ~~~~~~~~~~~~~~~~~~~~~~

    Run installation tests.

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the SaltStack Team, see AUTHORS for more details.
    :license: Apache 2.0, see LICENSE for more details.
'''

import glob
import shutil
from bootstrap.unittesting import *


CLEANUP_COMMANDS_BY_OS_FAMILY = {
    'Arch': [
        'pacman -Qs python2-crypto && pacman -Rsc --noconfirm python2-crypto && exit $? || exit 0',
        'pacman -Qs python2-distribute && pacman -Rsc --noconfirm python2-distribute && exit $? || exit 0',
        'pacman -Qs python2-jinja && pacman -Rsc --noconfirm python2-jinja && exit $? || exit 0',
        'pacman -Qs python2-m2crypto && pacman -Rsc --noconfirm python2-m2crypto && exit $? || exit 0',
        'pacman -Qs python2-markupsafe && pacman -Rsc --noconfirm python2-markupsafe && exit $? || exit 0',
        'pacman -Qs python2-msgpack && pacman -Rsc --noconfirm python2-msgpack && exit $? || exit 0',
        'pacman -Qs python2-psutil && pacman -Rsc --noconfirm python2-psutil && exit $? || exit 0',
        'pacman -Qs python2-pyzmq && pacman -Rsc --noconfirm python2-pyzmq && exit $? || exit 0',
        'pacman -Qs zeromq && pacman -Rsc --noconfirm zeromq && exit $? || exit 0',
    ],
    'Debian': [
        'apt-get remove -y -o DPkg::Options::=--force-confold '
        '--purge salt-master salt-minion salt-syndic',
        'apt-get autoremove -y -o DPkg::Options::=--force-confold --purge'
    ],
    'RedHat': [
        'yum -y remove salt-minion salt-master',
        'yum -y remove git python{0}-m2crypto m2crypto python{0}-crypto '
        'python{0}-msgpack python{0}-zmq python{0}-jinja2'.format(
            GRAINS['osrelease'].split('.')[0] == '5' and '26' or ''
        ),
    ],
    'FreeBSD': [
        'pkg delete -y swig sysutils/py-salt',
        'pkg autoremove -y'
    ],
    'Solaris': [
        'pkgin -y rm libtool-base autoconf automake libuuid gcc-compiler '
        'gmake py27-setuptools py27-yaml py27-crypto swig',
        'svcs network/salt-minion >/dev/null 2>&1 && svcadm disable network/salt-minion >/dev/null 2>&1 || exit 0',
        'svcs network/salt-minion >/dev/null 2>&1 && svccfg delete network/salt-minion >/dev/null 2>&1 || exit 0',
        'svcs network/salt-master >/dev/null 2>&1 && svcadm disable network/salt-master >/dev/null 2>&1 || exit 0',
        'svcs network/salt-master >/dev/null 2>&1 && svccfg delete network/salt-master >/dev/null 2>&1 || exit 0',
        'svcs network/salt-syndic >/dev/null 2>&1 && svcadm disable network/salt-syndic >/dev/null 2>&1 || exit 0',
        'svcs network/salt-syndic >/dev/null 2>&1 && svccfg delete network/salt-syndic >/dev/null 2>&1 || exit 0'
    ],
    'Suse': [
        '(zypper --non-interactive se -i salt-master || exit 0 && zypper --non-interactive remove salt-master && exit 0) || '
        '(rpm -q salt-master && rpm -e --noscripts salt-master || exit 0)',
        '(zypper --non-interactive se -i salt-minion || exit 0 && zypper --non-interactive remove salt-minion && exit 0) || '
        '(rpm -q salt-minion && rpm -e --noscripts salt-minion || exit 0)',
        '(zypper --non-interactive se -i salt-syndic || exit 0 && zypper --non-interactive remove salt-syndic && exit 0) || '
        '(rpm -q salt-syndic && rpm -e --noscripts salt-syndic || exit 0)',
        '(zypper --non-interactive se -i salt || exit 0 && zypper --non-interactive remove salt && exit 0) || '
        '(rpm -q salt && rpm -e --noscripts salt || exit 0)',
        'pip uninstall -y salt >/dev/null 2>&1 || exit 0',
        'pip uninstall -y PyYaml >/dev/null 2>&1 || exit 0',
        'zypper --non-interactive remove libzmq3 python-Jinja2 '
        'python-M2Crypto python-PyYAML python-msgpack-python '
        'python-pycrypto python-pyzmq',
    ]
}

# SLES grains differ from openSUSE, let do a 1:1 direct mapping
CLEANUP_COMMANDS_BY_OS_FAMILY['SUSE  Enterprise Server'] = CLEANUP_COMMANDS_BY_OS_FAMILY['Suse']


class InstallationTestCase(BootstrapTestCase):

    def setUp(self):
        if os.geteuid() is not 0:
            self.skipTest('you must be root to run this test')

        if GRAINS['os_family'] not in CLEANUP_COMMANDS_BY_OS_FAMILY:
            self.skipTest(
                'There is not `tearDown()` clean up support for {0!r} OS '
                'family.'.format(
                    GRAINS['os_family']
                )
            )

    def tearDown(self):
        for cleanup in CLEANUP_COMMANDS_BY_OS_FAMILY[GRAINS['os_family']]:
            print 'Running cleanup command {0!r}'.format(cleanup)
            self.assert_script_result(
                'Failed to execute cleanup command {0!r}'.format(cleanup),
                (
                    0,    # Proper exit code without errors.

                    4,    # ZYPPER_EXIT_ERR_ZYPP: A problem reported by ZYPP
                          # library.

                    65,   # FreeBSD throws this error code when the packages
                          # being un-installed were not installed in the first
                          # place.

                    100,  # Same as above but on Ubuntu with a another errno

                    104,  # ZYPPER_EXIT_INF_CAP_NOT_FOUND: Returned by the
                          # install and the remove command in case any of
                          # the arguments does not match any of the available
                          # (or installed) package names or other capabilities.
                ),
                self.run_script(
                    script=None,
                    args=cleanup.split(),
                    timeout=15 * 60,
                    stream_stds=True
                )
            )

        # As a last resort, by hand house cleaning...
        for glob_rule in ('/tmp/git', '/usr/lib*/python*/site-packages/salt*',
                          '/usr/bin/salt*', '/usr/lib/systemd/system/salt*',
                          '/etc/init*/salt*', '/usr/share/doc/salt*',
                          '/usr/share/man/man*/salt*', '/var/*/salt*',
                          '/etc/salt'):
            for entry in glob.glob(glob_rule):
                if os.path.isfile(entry):
                    print 'Removing file {0!r}'.format(entry)
                    os.remove(entry)
                elif os.path.isdir(entry):
                    print 'Removing directory {0!r}'.format(entry)
                    shutil.rmtree(entry)

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

        # Try to get the versions report
        self.assert_script_result(
            'Failed to the versions report',
            0,
            self.run_script(
                script=None,
                args=('salt-minion', '--versions-report'),
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

        # Try to get the versions report
        self.assert_script_result(
            'Failed to the versions report',
            0,
            self.run_script(
                script=None,
                args=('salt-minion', '--versions-report'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_install_explicit_stable(self):
        self.assert_script_result(
            'Failed to install explicit stable using sh',
            0,
            self.run_script(
                args=('stable',),
                timeout=15 * 60,
                stream_stds=True
            )
        )

        # Try to get the versions report
        self.assert_script_result(
            'Failed to the versions report',
            0,
            self.run_script(
                script=None,
                args=('salt-minion', '--versions-report'),
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

            # Try to get the versions report
            self.assert_script_result(
                'Failed to the versions report',
                0,
                self.run_script(
                    script=None,
                    args=('salt-minion', '--versions-report'),
                    timeout=15 * 60,
                    stream_stds=True
                )
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
                script=None,
                args='cat {0} | sh '.format(BOOTSTRAP_SCRIPT_PATH).split(),
                timeout=15 * 60,
                stream_stds=True
            )
        )

        # Try to get the versions report
        self.assert_script_result(
            'Failed to the versions report',
            0,
            self.run_script(
                script=None,
                args=('salt-minion', '--versions-report'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_install_latest_from_git_develop(self):
        self.assert_script_result(
            'Failed to install using latest git develop',
            0,
            self.run_script(
                args=('git', 'develop'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

        # Try to get the versions report
        self.assert_script_result(
            'Failed to the versions report',
            0,
            self.run_script(
                script=None,
                args=('salt', '--versions-report'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_install_specific_git_tag(self):
        self.assert_script_result(
            'Failed to install using specific git tag',
            0,
            self.run_script(
                args=('git', 'v0.13.1'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

        # Try to get the versions report
        self.assert_script_result(
            'Failed to the versions report',
            0,
            self.run_script(
                script=None,
                args=('salt', '--versions-report'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_install_specific_git_sha(self):
        self.assert_script_result(
            'Failed to install using specific git sha',
            0,
            self.run_script(
                args=('git', '2b6264de62bf2ea221bb2c0b8af36dfcfaafe7cf'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

        # Try to get the versions report
        self.assert_script_result(
            'Failed to the versions report',
            0,
            self.run_script(
                script=None,
                args=('salt', '--versions-report'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_config_only_without_config_dir_fails(self):
        '''
        Test running in configuration mode only without providing the necessary
        configuration directory fails.
        '''
        self.assert_script_result(
            'The script successfully executed even though no configuration '
            'directory was provided.',
            1,
            self.run_script(args=('-C',))
        )

    def test_config_with_a_non_existing_configuration_dir_fails(self):
        '''
        Do we fail if the passed configuration directory passed does not exits?
        '''
        self.assert_script_result(
            'The script successfully executed even though the configuration '
            'directory provided does not exist.',
            1,
            self.run_script(
                args=('-C', '-c', '/tmp/this-directory-must-not-exist')
            )
        )

    def test_config_only_without_actually_configuring_anything_fails(self):
        '''
        Test running in configuration mode only without actually configuring
        anything fails.
        '''
        self.assert_script_result(
            'The script successfully executed even though no configuration '
            'was done.',
            1,
            self.run_script(args=('-C', '-c', '/tmp'))
        )

    def test_install_salt_master(self):
        '''
        Test if installing a salt-master works
        '''
        self.assert_script_result(
            'Failed to install salt-master',
            0,
            self.run_script(
                args=('-N', '-M'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

        # Try to get the versions report
        self.assert_script_result(
            'Failed to get the versions report from salt-master',
            0,
            self.run_script(
                script=None,
                args=('salt-master', '--versions-report'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

    def test_install_salt_syndic(self):
        '''
        Test if installing a salt-syndic works
        '''
        self.assert_script_result(
            'Failed to install salt-syndic',
            0,
            self.run_script(
                args=('-N', '-S'),
                timeout=15 * 60,
                stream_stds=True
            )
        )

        # Try to get the versions report
        self.assert_script_result(
            'Failed to get the versions report from salt-syndic',
            0,
            self.run_script(
                script=None,
                args=('salt-syndic', '--versions-report'),
                timeout=15 * 60,
                stream_stds=True
            )
        )
