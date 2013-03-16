Salt Bootstrap Script - Integration Testing
===========================================

Testing ``salt-bootstrap`` requires both Python and Perl.

Yes, it's weird that a shell script uses either one of the above languages for testing itself, the 
explanation though, is simple.

Perl is required because we use a script, `checkbashisms`_, which does exactly what it's name says. 
In our case, it tries it's best to find non ``POSIX`` compliant code in our bootstrap script since 
we require the script to be able to properly execute in any ``POSIX`` compliant shell.

Python is used in the integration tests. It greatly simplifies running these tests and can even 
provide some JUnit compliant XML used to generate reports of those tests. Doing this job in shell 
scripting would be too cumbersome and too complicated.

Running the tests suite
-----------------------

.. warning:: The test suite is **destructive**. It will install/un-install packages on your system.
 You must run the suite using ``sudo`` or most / all of the tests will be skipped.

Running the tests suite is as simple as:

.. code:: console

  sudo python tests/runtests.py

For additional information on the available options:

.. code:: console

  python tests/runtests.py --help



.. _`checkbashisms`: http://sourceforge.net/projects/checkbaskisms/
.. vim: fenc=utf-8 spell spl=en cc=100 tw=99 fo=want sts=2 sw=2 et
