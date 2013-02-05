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
import shutil
import optparse

from bootstrap import TestLoader, TextTestRunner
try:
    from bootstrap.ext import console
    width, height = console.getTerminalSize()
    PNUM = width
except:
    PNUM = 70

try:
    import xmlrunner
except ImportError:
    xmlrunner = None


TEST_DIR = os.path.abspath(os.path.dirname(__file__))
XML_OUTPUT_DIR = os.environ.get(
    'XML_TEST_REPORTS', os.path.join(TEST_DIR, 'xml-test-reports')
)


def print_header(header, sep='~', top=True, bottom=True, inline=False,
                 centered=False):
    '''
    Allows some pretty printing of headers on the console, either with a
    "ruler" on bottom and/or top, inline, centered, etc.
    '''
    if top and not inline:
        print(sep * PNUM)

    if centered and not inline:
        fmt = u'{0:^{width}}'
    elif inline and not centered:
        fmt = u'{0:{sep}<{width}}'
    elif inline and centered:
        fmt = u'{0:{sep}^{width}}'
    else:
        fmt = u'{0}'
    print(fmt.format(header, sep=sep, width=PNUM))

    if bottom and not inline:
        print(sep * PNUM)


def run_suite(opts, path, display_name, suffix='[!_]*.py'):
    '''
    Execute a unit test suite
    '''
    loader = TestLoader()
    tests = loader.discover(path, suffix, TEST_DIR)

    header = '{0} Tests'.format(display_name)
    print_header('Starting {0}'.format(header))

    if opts.xmlout:
        if not os.path.isdir(XML_OUTPUT_DIR):
            os.makedirs(XML_OUTPUT_DIR)
        runner = xmlrunner.XMLTestRunner(
            output=XML_OUTPUT_DIR,
            verbosity=opts.verbosity
        ).run(tests)
    else:
        runner = TextTestRunner(
            verbosity=opts.verbosity
        ).run(tests)
    return runner.wasSuccessful()


def run_integration_suite(opts, display_name, suffix='[!_]*.py'):
    '''
    Run an integration test suite
    '''
    path = os.path.join(TEST_DIR, 'bootstrap')
    return run_suite(opts, path, display_name, suffix)


def main():
    parser = optparse.OptionParser()

    test_selection_group = optparse.OptionGroup(
        parser,
        "Tests Selection",
        "In case of no selection, all tests will be executed."
    )
    test_selection_group.add_option(
        '-L', '--lint',
        default=False,
        action='store_true',
        help='Run Lint tests'
    )
    test_selection_group.add_option(
        '-U', '--usage',
        default=False,
        action='store_true',
        help='Run Usage tests'
    )
    test_selection_group.add_option(
        '-I', '--install',
        default=False,
        action='store_true',
        help='Run Installation tests'
    )
    parser.add_option_group(test_selection_group)

    output_options_group = optparse.OptionGroup(parser, "Output Options")
    output_options_group.add_option(
        '-v',
        '--verbose',
        dest='verbosity',
        default=1,
        action='count',
        help='Verbose test runner output'
    )
    output_options_group.add_option(
        '-x',
        '--xml',
        dest='xmlout',
        default=False,
        action='store_true',
        help='XML test runner output(Output directory: {0})'.format(
            XML_OUTPUT_DIR
        )
    )
    output_options_group.add_option(
        '--no-clean',
        default=False,
        action='store_true',
        help='Do not clean the XML output files before running.'
    )
    parser.add_option_group(output_options_group)

    options, _ = parser.parse_args()

    if options.xmlout and xmlrunner is None:
        parser.error(
            '\'--xml\' is not available. The xmlrunner library is not '
            'installed.'
        )
    elif options.xmlout:
        print(
            'Generated XML reports will be stored on {0!r}'.format(
                XML_OUTPUT_DIR
            )
        )

    if not any((options.lint, options.usage, options.install)):
        options.lint = True
        options.usage = True
        options.install = True

    if not options.no_clean and os.path.isdir(XML_OUTPUT_DIR):
        shutil.rmtree(XML_OUTPUT_DIR)

    overall_status = []

    if options.lint:
        status = run_integration_suite(options, 'Lint', "*lint.py")
        overall_status.append(status)
    if options.usage:
        run_integration_suite(options, 'Usage', "*usage.py")
        overall_status.append(status)
    if options.install:
        run_integration_suite(options, 'Installation', "*install.py")
        overall_status.append(status)

    if overall_status.count(False) > 0:
        # We have some false results, the test-suite failed
        parser.exit(1)

    parser.exit(0)

if __name__ == '__main__':
    main()
