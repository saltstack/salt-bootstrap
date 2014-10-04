#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''
    test-bootstrap.py
    ~~~~~~~~~~~~~~~~~

    salt-bootstrap script unit-testing

    :codeauthor: :email:`Pedro Algarvio (pedro@algarvio.me)`
    :copyright: © 2013 by the SaltStack Team, see AUTHORS for more details.
    :license: Apache 2.0, see LICENSE for more details.
'''

import os
import pprint
import tempfile

TEST_DIR = os.path.abspath(os.path.dirname(__file__))
XML_OUTPUT_DIR = os.environ.get(
    'XML_TEST_REPORTS', os.path.join(
        tempfile.gettempdir(), 'xml-test-reports'
    )
)
HTML_OUTPUT_DIR = os.environ.get(
    'HTML_OUTPUT_DIR', os.path.join(
        tempfile.gettempdir(), 'html-test-results'
    )
)

from salttesting.parser import SaltTestingParser
from salttesting.ext.os_data import GRAINS


class BootstrapSuiteParser(SaltTestingParser):

    def setup_additional_options(self):
        self.test_selection_group.add_option(
            '-L', '--lint',
            default=False,
            action='store_true',
            help='Run Lint tests'
        )
        self.test_selection_group.add_option(
            '-U', '--usage',
            default=False,
            action='store_true',
            help='Run Usage tests'
        )
        self.test_selection_group.add_option(
            '-I', '--install',
            default=False,
            action='store_true',
            help='Run Installation tests'
        )
        self.test_selection_group.add_option(
            '--stable-salt-version',
            default='v2014.1.10',
            help='Specify the current stable release of salt'
        )

    def run_integration_suite(self, display_name, suffix='[!_]*.py'):
        '''
        Run an integration test suite
        '''
        return self.run_suite(
            os.path.join(TEST_DIR, 'bootstrap'),
            display_name,
            suffix
        )


def main():
    parser = BootstrapSuiteParser(
        TEST_DIR,
        xml_output_dir=XML_OUTPUT_DIR,
        html_output_dir=HTML_OUTPUT_DIR,
        tests_logfile=os.path.join(tempfile.gettempdir(), 'bootstrap-runtests.log')
    )

    options, _ = parser.parse_args()

    if not any((options.lint, options.usage, options.install, options.name)):
        options.lint = True
        options.usage = True
        options.install = True

    print 'Detected system grains:'
    pprint.pprint(GRAINS)

    # Set the current stable version of salt
    os.environ['CURRENT_SALT_STABLE_VERSION'] = options.stable_salt_version

    overall_status = []

    if options.name:
        for name in options.name:
            results = parser.run_suite('', name)
            overall_status.append(results)
    if options.lint:
        status = parser.run_integration_suite('Lint', '*lint.py')
        overall_status.append(status)
    if options.usage:
        status = parser.run_integration_suite('Usage', '*usage.py')
        overall_status.append(status)
    if options.install:
        status = parser.run_integration_suite('Installation', '*install.py')
        overall_status.append(status)

    if overall_status.count(False) > 0:
        parser.finalize(1)
    parser.finalize(0)


if __name__ == '__main__':
    main()
