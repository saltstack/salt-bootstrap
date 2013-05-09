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
import shutil
import optparse

from bootstrap.unittesting import TestLoader, TextTestRunner
from bootstrap.ext.os_data import GRAINS
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
TEST_RESULTS = []
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
    if opts.name:
        tests = tests = loader.loadTestsFromName(display_name)
    else:
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
        TEST_RESULTS.append((header, runner))
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
    test_selection_group.add_option(
        '-n', '--name',
        action='append',
        default=[],
        help='Specific test to run'
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

    if not any((options.lint, options.usage, options.install, options.name)):
        options.lint = True
        options.usage = True
        options.install = True

    if not options.no_clean and os.path.isdir(XML_OUTPUT_DIR):
        shutil.rmtree(XML_OUTPUT_DIR)

    print 'Detected system grains:'
    pprint.pprint(GRAINS)

    overall_status = []

    if options.name:
        for name in options.name:
            results = run_suite(options, '', name)
            overall_status.append(results)
    if options.lint:
        status = run_integration_suite(options, 'Lint', "*lint.py")
        overall_status.append(status)
    if options.usage:
        status = run_integration_suite(options, 'Usage', "*usage.py")
        overall_status.append(status)
    if options.install:
        status = run_integration_suite(options, 'Installation', "*install.py")
        overall_status.append(status)

    print
    print_header(
        u'  Overall Tests Report  ', sep=u'=', centered=True, inline=True
    )

    no_problems_found = True
    for (name, results) in TEST_RESULTS:
        if not results.failures and not results.errors and not results.skipped:
            continue

        no_problems_found = False

        print_header(u'*** {0}  '.format(name), sep=u'*', inline=True)
        if results.skipped:
            print_header(u' --------  Skipped Tests  ', sep='-', inline=True)
            maxlen = len(
                max([tc.id() for (tc, reason) in results.skipped], key=len)
            )
            fmt = u'   -> {0: <{maxlen}}  ->  {1}'
            for tc, reason in results.skipped:
                print(fmt.format(tc.id(), reason, maxlen=maxlen))
            print_header(u' ', sep='-', inline=True)

        if results.errors:
            print_header(
                u' --------  Tests with Errors  ', sep='-', inline=True
            )
            for tc, reason in results.errors:
                print_header(
                    u'   -> {0}  '.format(tc.id()), sep=u'.', inline=True
                )
                for line in reason.rstrip().splitlines():
                    print('       {0}'.format(line.rstrip()))
                print_header(u'   ', sep=u'.', inline=True)
            print_header(u' ', sep='-', inline=True)

        if results.failures:
            print_header(u' --------  Failed Tests  ', sep='-', inline=True)
            for tc, reason in results.failures:
                print_header(
                    u'   -> {0}  '.format(tc.id()), sep=u'.', inline=True
                )
                for line in reason.rstrip().splitlines():
                    print('       {0}'.format(line.rstrip()))
                print_header(u'   ', sep=u'.', inline=True)
            print_header(u' ', sep='-', inline=True)

        print_header(u'', sep=u'*', inline=True)

    if no_problems_found:
        print_header(
            u'***  No Problems Found While Running Tests  ',
            sep=u'*', inline=True
        )

    print_header(
        '  Overall Tests Report  ', sep='=', centered=True, inline=True
    )

    if overall_status.count(False) > 0:
        # We have some false results, the test-suite failed
        parser.exit(1)

    parser.exit(0)

if __name__ == '__main__':
    main()
