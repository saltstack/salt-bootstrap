==================
Bootstrapping Salt
==================

|build|

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

Also, to secure your Salt installation, check out these instructions for `hardening salt`_.

Bootstrap
=========

In every two-step installation example, you would be well-served to **verify against the SHA256
sum** of the downloaded ``bootstrap-salt.sh`` file.

The SHA256 sum of the ``bootstrap-salt.sh`` file, per release, is:

- 2020.06.23: ``1d07db867c195c864d0ae70664524f2099cc9a46872953293c67c3f239d4f4f5``
- 2020.05.28: ``6b3ea15c78f01060ab12fc01c0bb18480eaf36858c7ba188b200c0fb11aac173``
- 2020.02.24: ``efc46700aca78b8e51d7af9b06293f52ad495f3a8179c6bfb21a8c97ee41f1b7``
- 2020.02.04: ``ce877651b4938e3480f76b1629f582437f6ca8b73d7199fdb9e905e86fe85b34``
- 2020.01.29: ``e9afdfa877998c1c7f0e141a6728b33d0d24348e197aab2b9bde4fe6bc6db1b2``
- 2020.01.21: ``53299aa0dfbf7ab381f3856bb7babfc04a1d6525be11db0b9466277b1e4d0c1a``
- 2019.11.04: ``905924fccd4ebf168d19ba598bf10af53efe02302b792aeb15433e73fd3ad1d2``
- 2019.10.03: ``34f196f06d586ce9e1b9907660ea6e67caf57abcecfea66e0343697e3fd0d17d``
- 2019.05.20: ``46fb5e4b7815efafd69fd703f033fe86e7b584b6770f7e0b936995bcae1cedd8``
- 2019.02.27: ``23728e4b5e54f564062070e3be53c5602b55c24c9a76671968abbf3d609258cb``
- 2019.01.08: ``ab7f29b75711da4bb79aff98d46654f910d569ebe3e908753a3c5119017bb163``
- 2018.08.15: ``6d414a39439a7335af1b78203f9d37e11c972b3c49c519742c6405e2944c6c4b``
- 2018.08.13: ``98284bdc2b5ebaeb619b22090374e42a68e8fdefe6bff1e73bd1760db4407ed0``
- 2018.04.25: ``e2e3397d6642ba6462174b4723f1b30d04229b75efc099a553e15ea727877dfb``
- 2017.12.13: ``c127b3aa4a8422f6b81f5b4a40d31d13cec97bf3a39bca9c11a28f24910a6895``
- 2017.08.17: ``909b4d35696b9867b34b22ef4b60edbc5a0e9f8d1ed8d05f922acb79a02e46e3``
- 2017.05.24: ``8c42c2e5ad3d4384ddc557da5c214ba3e40c056ca1b758d14a392c1364650e89``

If you're looking for a *one-liner* to install Salt, please scroll to the bottom and use the
instructions for `Installing via an Insecure One-Liner`_.

There are also .sha256 files for verifying against in the repo for the stable branch.  You can also
get the correct sha256 sum for the stable release from https://bootstrap.saltstack.com/sha256 and
https://winbootstrap.saltstack.com/sha256

Contributing
------------

The Salt Bootstrap project is open and encouraging to code contributions. Please review the
`Contributing Guidelines`_ for information on filing issues, fixing bugs, and submitting features.

The `Contributing Guidelines`_ also contain information about the Bootstrap release cadence and
process.

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
  sudo sh bootstrap-salt.sh git master

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
  sudo sh bootstrap-salt.sh -M -N git master

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
  sudo sh bootstrap-salt.sh git master

With python version 2, the following in-line code should always work:

.. code:: console

  python -c 'import urllib; print urllib.urlopen("https://bootstrap.saltstack.com").read()' > bootstrap-salt.sh
  sudo sh bootstrap-salt.sh git master

With python version 3:

.. code:: console

  python3 -c 'import urllib.request; print(urllib.request.urlopen("https://bootstrap.saltstack.com").read().decode("ascii"))' > bootstrap-salt.sh
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

Installing the latest master branch of Salt:

.. code:: console

  curl -L https://bootstrap.saltstack.com | sudo sh -s -- git master


Install on Windows
~~~~~~~~~~~~~~~~~~

Using ``PowerShell`` to install latest stable version:

.. code:: console

  Invoke-WebRequest -Uri https://winbootstrap.saltstack.com -OutFile C:\Temp\bootstrap-salt.ps1
  Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
  C:\Temp\bootstrap-salt.ps1
  Set-ExecutionPolicy -ExecutionPolicy Undefined -Scope CurrentUser


Using ``cygwin`` to install latest stable version:

.. code:: console

  curl -o bootstrap-salt.ps1 -L https://winbootstrap.saltstack.com
  "/cygdrive/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ./bootstrap-salt.ps1"


Supported Operating Systems
---------------------------

The salt-bootstrap script officially supports the distributions outlined in
`Salt's Supported Operating Systems`_ document, except for Solaris and AIX. The operating systems
listed below should reflect this document but may become out of date. If an operating system is
listed below, but is not listed on the official supported operating systems document, the level of
support is "best-effort".

Since Salt is written in Python, the packages available from `SaltStack's corporate repository`_
are CPU architecture independent and could be installed on any hardware supported by Linux kernel.
However, SaltStack does package Salt's binary dependencies only for ``x86_64`` (``amd64``) and
``AArch32`` (``armhf``). The latter is available only for Debian/Raspbian 8 platforms.

It is recommended to use ``git`` bootstrap mode as described above to install Salt on other
architectures, such as ``x86`` (``i386``), ``AArch64`` (``arm64``) or ``ARM EABI`` (``armel``).
You also may need to disable repository configuration and allow ``pip`` installations by providing
``-r`` and ``-P`` options to the bootstrap script, i.e.:

.. code:: console

  sudo sh bootstrap-salt.sh -r -P git master

**NOTE**

Bootstrap may fail to install Salt on the cutting-edge version of distributions with frequent
release cycles such as: Amazon Linux, Fedora, openSUSE Tumbleweed, or Ubuntu non-LTS. Check the
versions from the list below. Also, see the `Unsupported Distro`_ section.


Debian and derivatives
~~~~~~~~~~~~~~~~~~~~~~

- Cumulus Linux 2/3
- Debian GNU/Linux 7/8/9/10
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
- Amazon Linux 2
- CentOS 6/7/8
- Cloud Linux 6/7
- Fedora 30/31 (install latest stable from standard repositories)
- Oracle Linux 6/7
- Red Hat Enterprise Linux 6/7/8
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

- KDE neon (based on Ubuntu 18.04)
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
- FreeBSD 11/12

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
- Centos 8
- Debian 9
- Debian 10
- Fedora (only git installations)
- Ubuntu 16.04
- Ubuntu 18.04

On Fedora, PIP installation must be allowed (-P) due to incompatibility with the shipped Tornado
library.

Installing the Python 3 packages for Salt is done via the ``-x`` option:

.. code:: console

    sh bootstrap-salt.sh -x python3

See the ``-x`` option for more information.

The earliest release of Salt that supports Python3 is `2018.3.4`.

Tornado 5/6 Workaround
----------------------
Salt does not support tornado>=5.0 currently. This support will be included in an upcoming release.
In order to work around this requirement on OSs that no longer have the tornado 4 package
available in their repositories we are pip installing tornado<5.0 in the bootstrap script. This
requires the user to pass -P to the bootstrap script if installing via git to ensure tornado is pip
installed.  If a user does not pass this argument they will be warned that it is required for the
tornado 5 workaround. So far the OSs that are using this workaround are Debian 10, Centos 8 and
Fedora 31.

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

Updating Drone Pipelines
========================

You should install and configure the drone-cli as shown here: https://docs.drone.io/cli/install/

Make edits to .drone.jsonnet and then save them into the .drone.yml by doing the following:

.. code:: console

  drone jsonnet --format --stream
  drone sign saltstack/salt-bootstrap --save

.. _Contributing Guidelines: https://github.com/saltstack/salt-bootstrap/blob/develop/CONTRIBUTING.md
.. _Docker: https://www.docker.com/
.. _`pre-accepted Minion keys`: https://docs.saltstack.com/en/latest/topics/tutorials/preseed_key.html
.. _`read the source`: https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.sh
.. _`Salt`: https://saltstack.com/community/
.. _`Salt's Supported Operating Systems`: http://get.saltstack.com/rs/304-PHQ-615/images/SaltStack-Supported-Operating-Systems.pdf
.. _`SaltStack's corporate repository`: https://repo.saltstack.com/
.. _`SaltStack's Debian repository`: http://repo.saltstack.com/#debian
.. _`SaltStack's Ubuntu repository`: http://repo.saltstack.com/#ubuntu
.. _`Ubuntu's release schedule`: https://wiki.ubuntu.com/Releases
.. _Vagrant: http://www.vagrantup.com
.. _hardening salt: https://docs.saltstack.com/en/latest/topics/hardening.html

.. |build|  image:: https://drone.saltstack.com/api/badges/saltstack/salt-bootstrap/status.svg
    :target: https://drone.saltstack.com/saltstack/salt-bootstrap
    :alt: Build status on Linux

.. vim: fenc=utf-8 spell spl=en cc=100 tw=99 fo=want sts=2 sw=2 et
