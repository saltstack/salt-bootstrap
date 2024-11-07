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

Older versions of Salt prior to 3006 are no longer supported by this bootstrap script as they have
reached their End-Of-Life. Only onedir-based architecture versions of Salt are supported by this
bootstrap script.


Bootstrap
=========

In every two-step installation example, you would be well-served to **verify against the SHA256
sum** of the downloaded ``bootstrap-salt.sh`` file.

.. _sha256sums:

The SHA256 sum of the ``bootstrap-salt.sh`` file, per release, is:

- 2024.09.24: ``88e4e4cad4b115a7b721dd9c21d5ee5df390b5b73b63de48f99399146f43f371``
- 2024.07.23: ``7212b6b497b5c3d2bf15bfe5301625ec7bc1bf3e2949cd47d8e2073614935bf8``
- 2024.07.18: ``92a74e7ff8a9032a7713c2b3955991d66aaca08a4eb9494ce3dd66b5044f6bc3``
- 2024.07.16: ``4f76d1549c71d696a605f97645d8633b6269c4d9ae54b1fbdfedca1dcf893e7a``
- 2024.07.12: ``526f4a5383db308081a120e26988679238ca6add4bf7a82120cbe71d57ab826e``
- 2024.04.03: ``450ba5cde4af8d6cb5c56c66791f87b918bcda70ccdfb10abf3cc294143c8073``
- 2024.01.04: ``cebcbc67895e238d1cf0024922a7fe5c772b9aaba346490c8fa6193bb0d993d4``
- 2023.11.16: ``3757ed82161113fed4c711fd7332e922265eeeb54e6e4f657a08ea82d57cc3a2``
- 2023.11.07: ``91f8a3bfb8b14476f7793c7f20cec7bfc638c10c073786f9a8904a858a929784``
- 2023.08.03: ``963e559bdb85adecfbbec2c3b81190392bc59b24992e4491e919cd748eeafcb8``
- 2023.07.25: ``eaaaadaed40fe2e791d59a9e48f24449428a35ca61782d9139f1272c05524323``
- 2023.06.28: ``f45f5da8abee27ef385131f5cfa9382d3a15863d0a05688a0404d2f057b27776``
- 2023.04.26: ``516fa9cc2e258cb8484ff360b9674b46918f657985c21ca9301e42a3dd263d60``
- 2023.04.21: ``e364428aa7a25f8e2c5e18e36e222351724c6cf35a1d57158f3357cde1e0a0f0``
- 2023.04.06: ``994bf7e8bd92fe6d70d291c7562aff299f5651046b4e76dfa506cee0d9bb0843``

If you're looking for a *one-liner* to install Salt, please scroll to the bottom and use the
instructions for `Installing via an Insecure One-Liner`_.

There are also .sha256 files for verifying against in the repo for the stable branch.  You can also
get the correct sha256 sum for the stable release from https://bootstrap.saltproject.io/sha256 and
https://winbootstrap.saltproject.io/sha256

Contributing
------------

The Salt Bootstrap project is open and encouraging to code contributions. Please review the
`Contributing Guidelines`_ for information on filing issues, fixing bugs, and submitting features.

The `Contributing Guidelines`_ also contain information about the Bootstrap release cadence and
process.

Examples
--------

To view the latest options and descriptions for ``salt-bootstrap``, use ``-h`` and the terminal:

.. code:: console

  ./salt-bootstrap.sh -h

  Usage :  bootstrap-salt.sh [options] <install-type> [install-type-args]

  Installation types:
    - stable              Install latest stable release. This is the default
                          install type
    - stable [branch]     Install latest version on a branch. Only supported
                          for packages available at repo.saltproject.io
    - stable [version]    Install a specific version. Only supported for
                          packages available at repo.saltproject.io
                          To pin a 3xxx minor version, specify it as 3xxx.0
    - testing             RHEL-family specific: configure EPEL testing repo
    - git                 Install from the head of the master branch
    - git [ref]           Install from any git ref (such as a branch, tag, or
                          commit)

  Examples:
    - bootstrap-salt.sh
    - bootstrap-salt.sh stable
    - bootstrap-salt.sh stable 3006.7
    - bootstrap-salt.sh stable v3006.8
    - bootstrap-salt.sh testing
    - bootstrap-salt.sh git
    - bootstrap-salt.sh git 3007.1
    - bootstrap-salt.sh git v3007.1
    - bootstrap-salt.sh git 06f249901a2e2f1ed310d58ea3921a129f214358

  Options:
    -h  Display this message
    -v  Display script version
    -n  No colours
    -D  Show debug output
    -c  Temporary configuration directory
    -g  Salt Git repository URL. Default: https://github.com/saltstack/salt.git
    -w  Install packages from downstream package repository rather than
        upstream, saltstack package repository. This is currently only
        implemented for SUSE.
    -k  Temporary directory holding the minion keys which will pre-seed
        the master.
    -s  Sleep time used when waiting for daemons to start, restart and when
        checking for the services running. Default: 3
    -L  Also install salt-cloud and required python-libcloud package
    -M  Also install salt-master
    -S  Also install salt-syndic
    -W  Also install salt-api
    -N  Do not install salt-minion
    -X  Do not start daemons after installation
    -d  Disables checking if Salt services are enabled to start on system boot.
        You can also do this by touching /tmp/disable_salt_checks on the target
        host. Default: ${BS_FALSE}
    -P  Allow pip based installations. On some distributions the required salt
        packages or its dependencies are not available as a package for that
        distribution. Using this flag allows the script to use pip as a last
        resort method. NOTE: This only works for functions which actually
        implement pip based installations.
    -U  If set, fully upgrade the system prior to bootstrapping Salt
    -I  If set, allow insecure connections while downloading any files. For
        example, pass '--no-check-certificate' to 'wget' or '--insecure' to
        'curl'. On Debian and Ubuntu, using this option with -U allows obtaining
        GnuPG archive keys insecurely if distro has changed release signatures.
    -F  Allow copied files to overwrite existing (config, init.d, etc)
    -K  If set, keep the temporary files in the temporary directories specified
        with -c and -k
    -C  Only run the configuration function. Implies -F (forced overwrite).
        To overwrite Master or Syndic configs, -M or -S, respectively, must
        also be specified. Salt installation will be ommitted, but some of the
        dependencies could be installed to write configuration with -j or -J.
    -A  Pass the salt-master DNS name or IP. This will be stored under
        ${BS_SALT_ETC_DIR}/minion.d/99-master-address.conf
    -i  Pass the salt-minion id. This will be stored under
        ${BS_SALT_ETC_DIR}/minion_id
    -p  Extra-package to install while installing Salt dependencies. One package
        per -p flag. You are responsible for providing the proper package name.
    -H  Use the specified HTTP proxy for all download URLs (including https://).
        For example: http://myproxy.example.com:3128
    -b  Assume that dependencies are already installed and software sources are
        set up. If git is selected, git tree is still checked out as dependency
        step.
    -f  Force shallow cloning for git installations.
        This may result in an "n/a" in the version number.
    -l  Disable ssl checks. When passed, switches "https" calls to "http" where
        possible.
    -V  Install Salt into virtualenv
        (only available for Ubuntu based distributions)
    -a  Pip install all Python pkg dependencies for Salt. Requires -V to install
        all pip pkgs into the virtualenv.
        (Only available for Ubuntu based distributions)
    -r  Disable all repository configuration performed by this script. This
        option assumes all necessary repository configuration is already present
        on the system.
    -R  Specify a custom repository URL. Assumes the custom repository URL
        points to a repository that mirrors Salt packages located at
        repo.saltproject.io. The option passed with -R replaces the
        "repo.saltproject.io". If -R is passed, -r is also set. Currently only
        works on CentOS/RHEL and Debian based distributions.
    -J  Replace the Master config file with data passed in as a JSON string. If
        a Master config file is found, a reasonable effort will be made to save
        the file with a ".bak" extension. If used in conjunction with -C or -F,
        no ".bak" file will be created as either of those options will force
        a complete overwrite of the file.
    -j  Replace the Minion config file with data passed in as a JSON string. If
        a Minion config file is found, a reasonable effort will be made to save
        the file with a ".bak" extension. If used in conjunction with -C or -F,
        no ".bak" file will be created as either of those options will force
        a complete overwrite of the file.
    -q  Quiet salt installation from git (setup.py install -q)
    -x  Changes the Python version used to install Salt (default: Python 3)
        Python 2.7 is not longer supported.
    -Q  Quickstart, install the Salt master and the Salt minion.
        And automatically accept the minion key.

The Salt Bootstrap script has a wide variety of options that can be passed as
well as several ways of obtaining the bootstrap script itself. Note that the use of ``sudo``
is not needed when running these commands as the ``root`` user.

**NOTE**

The examples below show how to bootstrap Salt directly from GitHub or another Git repository.
Run the script without any parameters to get latest stable Salt packages for your system from
the `Salt Project's repository`_. See first example in the `Install using wget`_ section.


Install using curl
~~~~~~~~~~~~~~~~~~

If you want to install a package of a specific release version, from the Salt Project repo:

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh -P stable 3006.1

If you want to install a specific release version, based on the Git tags:

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh git v3006.1

Using ``curl`` to install latest development version from GitHub:

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh git master

To install a specific branch from a Git fork:

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh -g https://github.com/myuser/salt.git git mybranch

If all you want is to install a ``salt-master`` using latest Git:

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh -M -N git master

If your host has Internet access only via HTTP proxy, from the Salt Project repo:

.. code:: console

  PROXY='http://user:password@myproxy.example.com:3128'
  curl -o bootstrap-salt.sh -L -x "$PROXY" https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh -P -H "$PROXY" stable

If your host has Internet access only via HTTP proxy, installing via Git:

.. code:: console

  PROXY='http://user:password@myproxy.example.com:3128'
  curl -o bootstrap-salt.sh -L -x "$PROXY" https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh -H "$PROXY" git


Install using wget
~~~~~~~~~~~~~~~~~~

Using ``wget`` to install your distribution's stable packages:

.. code:: console

  wget -O bootstrap-salt.sh https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh

Installing a specific version from git using ``wget``:

.. code:: console

  wget -O bootstrap-salt.sh https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh git v3004.1

Installing a specific version package from the Salt Project repo using ``wget``:

.. code:: console

  wget -O bootstrap-salt.sh https://bootstrap.saltproject.io
  sudo sh bootstrap-salt.sh -P stable 3006.1

**NOTE**

On the above examples we added ``-P`` which will allow PIP packages to be installed if required.
However, the ``-P`` flag is not necessary for Git-based bootstraps.


Install using Python
~~~~~~~~~~~~~~~~~~~~

If you already have Python installed, ``python 3.10``, then it's as easy as:

.. code:: console

  python -m urllib "https://bootstrap.saltproject.io" > bootstrap-salt.sh
  sudo sh bootstrap-salt.sh -P stable 3006.1

With python version 3:

.. code:: console

  python3 -c 'import urllib.request; print(urllib.request.urlopen("https://bootstrap.saltproject.io").read().decode("ascii"))' > bootstrap-salt.sh
  sudo sh bootstrap-salt.sh git v3006.1

Note: Python 2.x is no longer supported given it reached it's End-Of-Life Jan. 1st, 2020


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

  curl -L https://bootstrap.saltproject.io | sudo sh

Using ``wget`` to install your distribution's stable packages:

.. code:: console

  wget -O - https://bootstrap.saltproject.io | sudo sh

Installing a target version package of Salt from the Salt Project repo:

.. code:: console

  curl -L https://bootstrap.saltproject.io | sudo sh -s -- stable 3006.8

Installing the latest master branch of Salt from git:

.. code:: console

  curl -L https://bootstrap.saltproject.io | sudo sh -s -- git master

Note: use of git is recommended for development environments, for example: testing new features of
Salt which have not yet been released.
It is recommended that production environments should use ``stable``.


Install on Windows
~~~~~~~~~~~~~~~~~~

Using ``PowerShell`` to install latest stable version:

.. code:: powershell

  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12'
  Invoke-WebRequest -Uri https://winbootstrap.saltproject.io -OutFile "$env:TEMP\bootstrap-salt.ps1"
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  & "$env:TEMP\bootstrap-salt.ps1"

Display information about the install script parameters:

.. code:: powershell

  Get-Help $env:TEMP\bootstrap-salt.ps1 -Detailed

Using ``cygwin`` to install latest stable version:

.. code:: console

  curl -o bootstrap-salt.ps1 -L https://winbootstrap.saltproject.io
  "/cygdrive/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; iex ./bootstrap-salt.ps1"


Supported Operating Systems
---------------------------

The salt-bootstrap script officially supports the distributions outlined in
`Salt's Supported Operating Systems
<https://docs.saltproject.io/salt/install-guide/en/latest/topics/salt-supported-operating-systems.html>`_
document, (BSD-based OSs, Solaris and AIX are no longer
supported).  The operating systems listed below should reflect this document but may become out of
date. If an operating system is listed below, but is not listed on the official supported operating
systems document, the level of support is "best-effort".

Since Salt is written in Python, the packages available from the `Salt Project's repository
<https://repo.saltproject.io/salt/py3>`_ are
CPU architecture independent and could be installed on any hardware supported by Linux kernel.
However, the Salt Project does package Salt's binary dependencies only for ``x86_64`` (``amd64``)
and ``AArch64`` (``arm64``).

It is recommended to use ``git`` bootstrap mode as described above to install Salt on other
architectures, such as ``x86`` (``i386``) or ``ARM EABI`` (``armel``).
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
- Debian GNU/Linux 9/10/11/12
- Devuan GNU/Linux 1/2/3/4/5
- Kali Linux 1.0 (based on Debian 7)
- Linux Mint Debian Edition 1 (based on Debian 8)
- Raspbian 8 (``armhf`` packages) and 9 (using ``git`` installation mode only)


Red Hat family
~~~~~~~~~~~~~~

- Amazon Linux 2012.3 and later
- Amazon Linux 2
- Amazon Linux 2023
- CentOS 7/8/9
- Cloud Linux 6/7
- Fedora 38/39/40 (install latest stable from standard repositories)
- Oracle Linux 7/8/9
- Red Hat Enterprise Linux 7/8/9
- Scientific Linux 7/8/9


SUSE family
~~~~~~~~~~~

- openSUSE Leap 15 (see note below)
- openSUSE Leap 42.3
- openSUSE Tumbleweed 2015
- SUSE Linux Enterprise Server 11 SP4, 12 SP2

**NOTE:** Leap 15 installs Python 3 Salt packages by default. Salt is packaged by SUSE, and
Leap 15 ships with Python 3.

.. code:: console

    sh bootstrap-salt.sh -x python3 git v3006.1


Ubuntu and derivatives
~~~~~~~~~~~~~~~~~~~~~~

- KDE neon (based on Ubuntu 20.04/22.04/24.04)
- Linux Mint 17/18

Ubuntu Best Effort Support: Non-LTS Releases
********************************************

This script provides best-effort support for current, non-LTS Ubuntu releases. If package
repositories are not provided on the `Salt Project's Ubuntu repository`_ for the non-LTS release,
the bootstrap script will attempt to install the packages for the most closely related LTS Ubuntu
release instead.

For example, when installing Salt on Ubuntu 21.10, the bootstrap script will setup the repository
for Ubuntu 20.04 from the `Salt Project's Ubuntu repository`_ and install the 20.04 packages.

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

- No longer supported

**SunOS**:

- No longer supported


Using a custom salt bootstrap
-----------------------------

By default the ``salt-cloud -p`` provisioning command will use the latest release from this
repository to bootstrap new minions. If

- your needs are not met by that script,
- you want to lock salt bootstrap to a specific release, or
- you want to use an unreleased development version of this script

you can add your bootstrap-salt script to your salt cloud configuration and point to it with the
``script`` attribute.

`Read more`: https://docs.saltproject.io/en/latest/topics/cloud/deploy.html


Unsupported Distributions
-------------------------

If you are running a Linux distribution that is not supported yet or is not correctly identified,
please run the following commands and report their output when creating an issue:

.. code:: console

  sudo find /etc/ -name \*-release -print -exec cat {} \;
  command lsb_release -a

For information on how to add support for a currently unsupported distribution, please refer to the
`Contributing Guidelines`_.

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

The ``Dockerfile`` here inherits the Ubuntu 20.04 public image. Use it as an example or starting
point of how to make your own Docker images with suitable Salt components, custom configurations,
and even `pre-accepted Minion keys`_ already installed.

.. vim: fenc=utf-8 spell spl=en cc=100 tw=99 fo=want sts=2 sw=2 et
