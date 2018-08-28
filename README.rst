==================
Bootstrapping Salt
==================

|windows_build|

.. contents::
    :local:

Before `Salt`_ can be used for provisioning on the desired machine, the binaries need to be
installed. Since `Salt`_ supports many different distributions and versions of operating systems,
the `Salt`_ installation process is handled by this shell script ``bootstrap-salt.sh``.  This
script runs through a series of checks to determine operating system type and version to then
install the `Salt`_ binaries using the appropriate methods. For Windows, use the
``bootstrap-salt.ps1`` script.

**NOTE**

This ``README`` file is not the absolute truth as to what the bootstrap script is capable of. For
that, please read the generated help by passing ``-h`` to the script or even better,
`read the source`_.

Bootstrap
=========

In every two-step installation example, you would be well-served to **verify against the SHA256
sum** of the downloaded ``bootstrap-salt.sh`` file.

The SHA256 sum of the ``bootstrap-salt.sh`` file, per release, is:

- 2018.08.15: ``6d414a39439a7335af1b78203f9d37e11c972b3c49c519742c6405e2944c6c4b``
- 2018.08.13: ``98284bdc2b5ebaeb619b22090374e42a68e8fdefe6bff1e73bd1760db4407ed0``
- 2018.04.25: ``e2e3397d6642ba6462174b4723f1b30d04229b75efc099a553e15ea727877dfb``
- 2017.12.13: ``c127b3aa4a8422f6b81f5b4a40d31d13cec97bf3a39bca9c11a28f24910a6895``
- 2017.08.17: ``909b4d35696b9867b34b22ef4b60edbc5a0e9f8d1ed8d05f922acb79a02e46e3``
- 2017.05.24: ``8c42c2e5ad3d4384ddc557da5c214ba3e40c056ca1b758d14a392c1364650e89``

If you're looking for a *one-liner* to install Salt, please scroll to the bottom and use the
instructions for `Installing via an Insecure One-Liner`_.

Contributing
------------

The Salt Bootstrap project is open and encouraging to code contributions. Please review the
`Contributing Guidelines`_ for information on filing issues, fixing bugs, and submitting features.

Examples
--------

The Salt Bootstrap script has a wide variety of options that can be passed as
well as several ways of obtaining the bootstrap script itself. Note that the use of ``sudo``
is not needed when running these commands as the ``root`` user.

**NOTE**

The examples below show how to bootstrap Salt directly from GitHub or another Git repository.
Run the script without any parameters to get latest stable Salt packages for your system from
`SaltStack's corporate repository`_. See first example in the `Install using wget`_ section.


Install using curl
~~~~~~~~~~~~~~~~~~

Using ``curl`` to install latest development version from GitHub:

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com
  sudo sh bootstrap-salt.sh git develop

If you want to install a specific release version (based on the Git tags):

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com
  sudo sh bootstrap-salt.sh git v2016.11.5

To install a specific branch from a Git fork:

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com
  sudo sh bootstrap-salt.sh -g https://github.com/myuser/salt.git git mybranch

If all you want is to install a ``salt-master`` using latest Git:

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com
  sudo sh bootstrap-salt.sh -M -N git develop

If your host has Internet access only via HTTP proxy:

.. code:: console

  PROXY='http://user:password@myproxy.example.com:3128'
  curl -o bootstrap-salt.sh -L -x "$PROXY" https://bootstrap.saltstack.com
  sudo sh bootstrap-salt.sh -H "$PROXY" git


Install using wget
~~~~~~~~~~~~~~~~~~

Using ``wget`` to install your distribution's stable packages:

.. code:: console

  wget -O bootstrap-salt.sh https://bootstrap.saltstack.com
  sudo sh bootstrap-salt.sh

Installing a specific version from git using ``wget``:

.. code:: console

  wget -O bootstrap-salt.sh https://bootstrap.saltstack.com
  sudo sh bootstrap-salt.sh -P git v2016.11.5

**NOTE**

On the above example we added ``-P`` which will allow PIP packages to be installed if required.
However, the ``-P`` flag is not necessary for Git-based bootstraps.


Install using Python
~~~~~~~~~~~~~~~~~~~~

If you already have Python installed, ``python 2.7``, then it's as easy as:

.. code:: console

  python -m urllib "https://bootstrap.saltstack.com" > bootstrap-salt.sh
  sudo sh bootstrap-salt.sh git develop

All Python versions should support the following in-line code:

.. code:: console

  python -c 'import urllib; print urllib.urlopen("https://bootstrap.saltstack.com").read()' > bootstrap-salt.sh
  sudo sh bootstrap-salt.sh git develop


Install using fetch
~~~~~~~~~~~~~~~~~~~

On a FreeBSD-based system you usually don't have either of the above binaries available. You **do**
have ``fetch`` available though:

.. code:: console

  fetch -o bootstrap-salt.sh https://bootstrap.saltstack.com
  sudo sh bootstrap-salt.sh

If you have any SSL issues install ``ca_root_nss``:

.. code:: console

  pkg install ca_root_nss

And either copy the certificates to the place where fetch can find them:

.. code:: console

  cp /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem

Or link them to the right place:

.. code:: console

  ln -s /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem


Installing via an Insecure One-Liner
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The following examples illustrate how to install Salt via a one-liner.

**NOTE**

Warning! These methods do not involve a verification step and assume that the delivered file is
trustworthy.

Any of the examples above which use two lines can be made to run in a single-line
configuration with minor modifications.

Installing the latest stable release of Salt (default):

.. code:: console

  curl -L https://bootstrap.saltstack.com | sudo sh

Using ``wget`` to install your distribution's stable packages:

.. code:: console

  wget -O - https://bootstrap.saltstack.com | sudo sh

Installing the latest develop branch of Salt:

.. code:: console

  curl -L https://bootstrap.saltstack.com | sudo sh -s -- git develop


Supported Operating Systems
---------------------------

The salt-bootstrap script officially supports the distributions outlined in
`Salt's Supported Operating Systems`_ document. The operating systems listed below should reflect
this document but may become out of date. If an operating system is listed below, but is not
listed on the official supported operating systems document, the level of support is "best-effort".

Since Salt is written in Python, the packages available from `SaltStack's corporate repository`_
are CPU architecture independent and could be installed on any hardware supported by Linux kernel.
However, SaltStack does package Salt's binary dependencies only for ``x86_64`` (``amd64``) and
``AArch32`` (``armhf``). The latter is available only for Debian/Raspbian 8 platforms.

It is recommended to use ``git`` bootstrap mode as described above to install Salt on other
architectures, such as ``x86`` (``i386``), ``AArch64`` (``arm64``) or ``ARM EABI`` (``armel``).
You also may need to disable repository configuration and allow ``pip`` installations by providing
``-r`` and ``-P`` options to the bootstrap script, i.e.:

.. code:: console

  sudo sh bootstrap-salt.sh -r -P git develop

**NOTE**

Bootstrap may fail to install Salt on the cutting-edge version of distributions with frequent
release cycles such as: Amazon Linux, Fedora, openSUSE Tumbleweed, or Ubuntu non-LTS. Check the
versions from the list below. Also, see the `Unsupported Distro`_ section.


Debian and derivatives
~~~~~~~~~~~~~~~~~~~~~~

- Cumulus Linux 2/3
- Debian GNU/Linux 7/8/9
- Devuan GNU/Linux 1/2
- Kali Linux 1.0 (based on Debian 7)
- Linux Mint Debian Edition 1 (based on Debian 8)
- Raspbian 8 (``armhf`` packages) and 9 (using ``git`` installation mode only)

Debian Best Effort Support: Testing Release
*******************************************

This script provides best-effort support for the upcoming Debian testing release. Package
repositories are not provided on `SaltStack's Debian repository`_ for Debian testing releases.
However, the bootstrap script will attempt to install the packages for the current stable
version of Debian.

For example, when installing Salt on Debian 10 (Buster), the bootstrap script will setup the
repository for Debian 9 (Stretch) from `SaltStack's Debian repository`_ and install the
Debian 9 packages.


Red Hat family
~~~~~~~~~~~~~~

- Amazon Linux 2012.3 and later
- CentOS 6/7
- Cloud Linux 6/7
- Fedora 27/28 (install latest stable from standard repositories)
- Oracle Linux 6/7
- Red Hat Enterprise Linux 6/7
- Scientific Linux 6/7


SUSE family
~~~~~~~~~~~

- openSUSE Leap 15 (see note below)
- openSUSE Leap 42.3
- openSUSE Tumbleweed 2015
- SUSE Linux Enterprise Server 11 SP4, 12 SP2

**NOTE:** Leap 15 installs Python 3 Salt packages by default. Salt is packaged by SUSE, and
Leap 15 ships with Python 3. Salt with Python 2 can be installed using the the ``-x`` option
in combination with the ``git`` installation method.

.. code:: console

    sh bootstrap-salt.sh -x python2 git v2018.3.2


Ubuntu and derivatives
~~~~~~~~~~~~~~~~~~~~~~

- KDE neon (based on Ubuntu 16.04)
- Linux Mint 17/18
- Ubuntu 14.04/16.04/18.04 and subsequent non-LTS releases (see below)

Ubuntu Best Effort Support: Non-LTS Releases
********************************************

This script provides best-effort support for current, non-LTS Ubuntu releases. If package
repositories are not provided on `SaltStack's Ubuntu repository`_ for the non-LTS release, the
bootstrap script will attempt to install the packages for the most closely related LTS Ubuntu
release instead.

For example, when installing Salt on Ubuntu 18.10, the bootstrap script will setup the repository
for Ubuntu 18.04 from `SaltStack's Ubuntu repository`_ and install the 18.04 packages.

Non-LTS Ubuntu releases are not supported once the release reaches End-of-Life as defined by
`Ubuntu's release schedule`_.


Other Linux distributions
~~~~~~~~~~~~~~~~~~~~~~~~~

- Alpine Linux 3.5/edge
- Arch Linux
- Gentoo


UNIX systems
~~~~~~~~~~~~

**BSD**:

- OpenBSD (``pip`` installation)
- FreeBSD 9/10/11

**SunOS**:

- SmartOS (2015Q4 and later)

Unsupported Distributions
-------------------------

If you are running a Linux distribution that is not supported yet or is not correctly identified,
please run the following commands and report their output when creating an issue:

.. code:: console

  sudo find /etc/ -name \*-release -print -exec cat {} \;
  command lsb_release -a

For information on how to add support for a currently unsupported distribution, please refer to the
`Contributing Guidelines`_.

Python 3 Support
----------------

Some distributions support installing Salt to use Python 3 instead of Python 2. The availability of
this offering, while limited, is as follows:

- CentOS 7
- Debian 9
- Fedora (only git installations)
- Ubuntu 16.04
- Ubuntu 18.04

On Fedora 28, PIP installation must be allowed (-P) due to incompatibility with the shipped Tornado library.

Installing the Python 3 packages for Salt is done via the ``-x`` option:

.. code:: console

    sh bootstrap-salt.sh -x python3

See the ``-x`` option for more information.

Testing
-------

There are a couple of ways to test the bootstrap script. Running the script on a fully-fledged
VM is one way. Other options include using Vagrant or Docker.

Testing in Vagrant
==================

Vagrant_ can be used to easily test changes on a clean machine. The ``Vagrantfile`` defaults to an
Ubuntu box. First, install Vagrant, then:

.. code:: console

  vagrant up
  vagrant ssh

Running in Docker
=================

It is possible to run and use Salt inside a Docker_ container on Linux machines.
Let's prepare the Docker image using the provided ``Dockerfile`` to install both a Salt Master
and a Salt Minion with the bootstrap script:

.. code:: console

  docker build -t local/salt-bootstrap .

Start your new container with Salt services up and running:

.. code:: console

  docker run --detach --name salt --hostname salt local/salt-bootstrap

And finally "enter" the running container and make Salt fully operational:

.. code:: console

  docker exec -i -t salt /bin/bash
  salt-key -A -y

Salt is ready and working in the Docker container with the Minion authenticated on the Master.

**NOTE**

The ``Dockerfile`` here inherits the Ubuntu 14.04 public image with Upstart configured as the init
system. Use it as an example or starting point of how to make your own Docker images with suitable
Salt components, custom configurations, and even `pre-accepted Minion keys`_ already installed.

.. _Contributing Guidelines: https://github.com/saltstack/salt-bootstrap/blob/develop/CONTRIBUTING.md
.. _Docker: https://www.docker.com/
.. _`pre-accepted Minion keys`: https://docs.saltstack.com/en/latest/topics/tutorials/preseed_key.html
.. _`read the source`: https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.sh
.. _`Salt`: https://saltstack.com/community/
.. _`Salt's Supported Operating Systems`: http://saltstack.com/wp-content/uploads/2016/08/SaltStack-Supported-Operating-Systems.pdf
.. _`SaltStack's corporate repository`: https://repo.saltstack.com/
.. _`SaltStack's Debian repository`: http://repo.saltstack.com/#debian
.. _`SaltStack's Ubuntu repository`: http://repo.saltstack.com/#ubuntu
.. _`Ubuntu's release schedule`: https://wiki.ubuntu.com/Releases
.. _Vagrant: http://www.vagrantup.com


.. |windows_build|  image:: https://ci.appveyor.com/api/projects/status/github/saltstack/salt-bootstrap?branch=develop&svg=true
    :target: https://ci.appveyor.com/project/saltstack-public/salt-bootstrap
    :alt: Build status of the develop branch on Windows

.. vim: fenc=utf-8 spell spl=en cc=100 tw=99 fo=want sts=2 sw=2 et
