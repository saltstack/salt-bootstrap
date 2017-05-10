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
install the `Salt`_ binaries using the appropriate methods.

.. note::

  This ``README`` file is not the absolute truth to what the bootstrap script is capable of, for
  that, please read the generated help by passing ``-h`` to the script or even better,
  `read the source`_.

**In case you found a bug, please read** `I Found a Bug`_ **first before submitting a new issue.**
The examples there show how to get the latest development version of the bootstrap script. Chances
are high that your issue was already fixed.


Bootstrap
=========

If you're looking for the *one-liner* to install Salt, please scroll to the bottom and use the
instructions for `Installing via an Insecure One-Liner`_.

.. note::

  In every two-step example, you would be well-served to examine the downloaded file and examine
  it to ensure that it does what you expect.


Examples
--------

The Salt Bootstrap script has a wide variety of options that can be passed as
well as several ways of obtaining the bootstrap script itself.

.. note::

  These examples below show how to bootstrap Salt directly from GitHub or other Git repository.
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
  sudo sh bootstrap-salt.sh git v2016.3.2

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
  sudo sh bootstrap-salt.sh -P git v2015.8.11

.. note::

  On the above example we added `-P` which will allow PIP packages to be installed if required but
  it's not a necessary flag for Git based bootstraps.


Install using Python
~~~~~~~~~~~~~~~~~~~~

If you already have Python installed, ``python 2.6``, then it's as easy as:

.. code:: console

  python -m urllib "https://bootstrap.saltstack.com" > bootstrap-salt.sh
  sudo sh bootstrap-salt.sh git develop

All Python versions should support the following in-line code:

.. code:: console

  python -c 'import urllib; print urllib.urlopen("https://bootstrap.saltstack.com").read()' > bootstrap-salt.sh
  sudo sh bootstrap-salt.sh git develop


Install using fetch
~~~~~~~~~~~~~~~~~~~

On a FreeBSD base system you usually don't have either of the above binaries available. You **do**
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
------------------------------------

The following examples illustrate how to install Salt via a one-liner.

.. note::

  Warning! These methods do not involve a verification step and assume that the delivered file is
  trustworthy.

Any of the example above which use two-lines can be made to run in a single-line
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
``AArch32`` (``armhf``), which is limited for Debian/Raspbian 8 platforms.

It is recommended to use ``git`` bootstrap mode as described above to install Salt on other
architectures, such as ``x86`` (``i386``), ``AArch64`` (``arm64``) or ``ARM EABI`` (``armel``).
You also may need to disable repository configuration and allow ``pip`` installations by providing
``-r`` and ``-P`` options to the bootstrap script, i.e.:

.. code:: console

  sudo sh bootstrap-salt.sh -r -P git develop

.. note::

  Bootstrap may fail to install Salt on the cutting-edge version of distributions with frequent
  release cycles such as: Amazon Linux, Fedora, openSUSE Tumbleweed, or Ubuntu non-LTS. Check the
  versions from the list below. Also, see the `Unsupported Distro`_ and
  `Adding Support for Other Operating Systems`_ sections.


Debian and derivatives
~~~~~~~~~~~~~~~~~~~~~~

- Cumulus Linux 2/3
- Debian GNU/Linux 7/8
- Linux Mint Debian Edition 1 (based on Debian 8)
- Kali Linux 1.0 (based on Debian 7)
- Raspbian 8 (``armhf``)


Red Hat family
~~~~~~~~~~~~~~

- Amazon Linux 2012.3 and later
- CentOS 6/7
- Cloud Linux 6/7
- Fedora 23/24/25
- Oracle Linux 6/7
- Red Hat Enterprise Linux 6/7
- Scientific Linux 6/7


SUSE family
~~~~~~~~~~~

- openSUSE 12/13
- openSUSE Leap 42
- openSUSE Tumbleweed 2015
- SUSE Linux Enterprise Server 11 SP1/11 SP2/11 SP3/12


Ubuntu and derivatives
~~~~~~~~~~~~~~~~~~~~~~

- Elementary OS 0.2 (based on Ubuntu 12.04)
- KDE neon (based on Ubuntu 16.04)
- Linaro 12.04
- Linux Mint 13/17/18
- Trisquel GNU/Linux 6 (based on Ubuntu 12.04)
- Ubuntu 12.04/14.04/16.04 and subsequent non-TLS releases (see below)

Ubuntu Best Effort Support: Non-LTS Releases 
********************************************

This script provides best-effort support for current, non-LTS Ubuntu releases. If package 
repositories are not provided on `SaltStack's Ubuntu repository`_ for the non-LTS release, the
bootstrap script will attempt to install the packages for the most closely related LTS Ubuntu
release instead.

For example, when installing Salt on Ubuntu 16.10, the bootstrap script will setup the repository 
for Ubuntu 16.04 from `SaltStack's Ubuntu repository`_ and install the 16.04 packages.


Other Linux distro
~~~~~~~~~~~~~~~~~~

- Alpine Linux 3.5/edge
- Arch Linux
- Gentoo


UNIX systems
~~~~~~~~~~~~

**BSD**:

- OpenBSD (``pip`` installation)
- FreeBSD 9/10/11

**SunOS**:

- SmartOS


Unsupported Distro
------------------

You found a Linux distribution which we still do not support or we do not correctly identify?
Please run the following commands and report their output when creating a ticket:

.. code:: console

  sudo find /etc/ -name \*-release -print -exec cat {} \;
  command lsb_release -a


Adding Support for Other Operating Systems
------------------------------------------

The following operating systems are detected, but Salt and its dependencies installation functions
are not developed yet:

**BSD**:

- NetBSD

**Linux**:

- Slackware

**SunOS**

- OpenIndiana
- Oracle Solaris
- OmniOS (Illumos)


In order to install Salt for a distribution you need to define:

1. To Install Dependencies, which is required, one of:

.. code:: bash

  install_<distro>_<major_version>_<install_type>_deps
  install_<distro>_<major_version>_<minor_version>_<install_type>_deps
  install_<distro>_<major_version>_deps
  install_<distro>_<major_version>_<minor_version>_deps
  install_<distro>_<install_type>_deps
  install_<distro>_deps


2. Optionally, define a minion configuration function, which will be called if the
   ``-c`` option is passed. One of:

.. code:: bash

  config_<distro>_<major_version>_<install_type>_salt
  config_<distro>_<major_version>_<minor_version>_<install_type>_salt
  config_<distro>_<major_version>_salt
  config_<distro>_<major_version>_<minor_version>_salt
  config_<distro>_<install_type>_salt
  config_<distro>_salt
  config_salt [THIS ONE IS ALREADY DEFINED AS THE DEFAULT]


3. Optionally, define a Salt master pre-seed function, which will be called if the
   ``-k`` (pre-seed master keys) option is passed. One of:

.. code:: bash

  preseed_<distro>_<major_version>_<install_type>_master
  preseed_<distro>_<major_version>_<minor_version>_<install_type>_master
  preseed_<distro>_<major_version>_master
  preseed_<distro>_<major_version>_<minor_version>_master
  preseed_<distro>_<install_type>_master
  preseed_<distro>_master
  preseed_master [THIS ONE IS ALREADY DEFINED AS THE DEFAULT]


4. To install salt, which, of course, is required, one of:

.. code:: bash

  install_<distro>_<major_version>_<install_type>
  install_<distro>_<major_version>_<minor_version>_<install_type>
  install_<distro>_<install_type>


5. Optionally, define a post install function, one of:

.. code:: bash

  install_<distro>_<major_version>_<install_type>_post
  install_<distro>_<major_version>_<minor_version>_<install_type>_post
  install_<distro>_<major_version>_post
  install_<distro>_<major_version>_<minor_version>_post
  install_<distro>_<install_type>_post
  install_<distro>_post


6. Optionally, define a start daemons function, one of:

.. code:: bash

  install_<distro>_<major_version>_<install_type>_restart_daemons
  install_<distro>_<major_version>_<minor_version>_<install_type>_restart_daemons
  install_<distro>_<major_version>_restart_daemons
  install_<distro>_<major_version>_<minor_version>_restart_daemons
  install_<distro>_<install_type>_restart_daemons
  install_<distro>_restart_daemons


.. admonition:: Attention!

  The start daemons function should be able to restart any daemons which are running, or start if
  they're not running.


7. Optionally, define a daemons running function, one of:

.. code:: bash

  daemons_running_<distro>_<major_version>_<install_type>
  daemons_running_<distro>_<major_version>_<minor_version>_<install_type>
  daemons_running_<distro>_<major_version>
  daemons_running_<distro>_<major_version>_<minor_version>
  daemons_running_<distro>_<install_type>
  daemons_running_<distro>
  daemons_running  [THIS ONE IS ALREADY DEFINED AS THE DEFAULT]


8. Optionally, check enabled Services:

.. code:: bash

  install_<distro>_<major_version>_<install_type>_check_services
  install_<distro>_<major_version>_<minor_version>_<install_type>_check_services
  install_<distro>_<major_version>_check_services
  install_<distro>_<major_version>_<minor_version>_check_services
  install_<distro>_<install_type>_check_services
  install_<distro>_check_services


----

Below is an example for Ubuntu Oneiric (the example may not be up to date with the script):

.. code:: bash

  install_ubuntu_11_10_deps() {
      apt-get update
      apt-get -y install python-software-properties
      add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
      add-apt-repository -y ppa:saltstack/salt
  }

  install_ubuntu_11_10_post() {
      add-apt-repository -y --remove 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
  }

  install_ubuntu_stable() {
      apt-get -y install salt-minion
  }

  install_ubuntu_restart_daemons() {
      for fname in minion master syndic; do

          # Skip if not meant to be installed
          [ $fname = "minion" ] && [ $INSTALL_MINION -eq $BS_FALSE ] && continue
          [ $fname = "master" ] && [ $INSTALL_MASTER -eq $BS_FALSE ] && continue
          [ $fname = "syndic" ] && [ $INSTALL_SYNDIC -eq $BS_FALSE ] && continue

          if [ -f /sbin/initctl ]; then
              # We have upstart support
              /sbin/initctl status salt-$fname > /dev/null 2>&1
              if [ $? -eq 0 ]; then
                  # upstart knows about this service, let's stop and start it.
                  # We could restart but earlier versions of the upstart script
                  # did not support restart, so, it's safer this way
                  /sbin/initctl stop salt-$fname > /dev/null 2>&1
                  /sbin/initctl start salt-$fname > /dev/null 2>&1
                  [ $? -eq 0 ] && continue
                  # We failed to start the service, let's test the SysV code bellow
              fi
          fi
          /etc/init.d/salt-$fname stop > /dev/null 2>&1
          /etc/init.d/salt-$fname start
      done
  }


Since there is no ``install_ubuntu_11_10_stable()`` it defaults to the unspecified version script.

The bootstrapping script must be plain POSIX ``sh`` only, **not** ``bash`` or another shell script.
By design the targeting for each operating system and version is very specific. Assumptions of
supported versions or variants should not be made, to avoid failed or broken installations.


I Found a Bug
=============

If you found a possible problem, or bug, please try to bootstrap using the develop version. The
issue you are having might have already been fixed and it's just not yet included in the stable
version.

.. code:: console

  curl -o bootstrap-salt.sh -L https://bootstrap.saltstack.com/develop
  sudo sh bootstrap-salt.sh git develop


Or the insecure one liner:

.. code:: console

  curl -L https://bootstrap.saltstack.com/develop | sudo sh -s -- git develop


If after trying this and the problem still occurs, please `file an issue`_.


Testing in Vagrant
==================

You can use Vagrant_ to easily test changes on a clean machine. The ``Vagrantfile`` defaults to an
Ubuntu box. First, install Vagrant, then:

.. code:: console

  vagrant up
  vagrant ssh


Running in Docker
=================

Also you are able to run and use Salt inside Docker_ container on Linux machine.
Let's prepare the Docker image using provided ``Dockerfile`` to install both Salt Master and Minion
with the bootstrap script:

.. code:: console

  docker build -t local/salt-bootstrap .

Start your new container with Salt services up and running:

.. code:: console

  docker run --detach --name salt --hostname salt local/salt-bootstrap

And finally "enter" the running container and make Salt fully operational:

.. code:: console

  docker exec -i -t salt /bin/bash
  salt-key -A -y

Salt is ready and working in the Docker container with Minion authenticated on Master.

.. note::

  The ``Dockerfile`` here inherits Ubuntu 14.04 public image with Upstart configured as init system.
  Consider it as an example or starting point of how to make your own Docker images with suitable
  Salt components, custom configurations and even `pre-accepted Minion key`_ already installed.


.. _Docker: https://www.docker.com/
.. _`file an issue`: https://github.com/saltstack/salt-bootstrap/issues/new
.. _`pre-accepted Minion key`: https://docs.saltstack.com/en/latest/topics/tutorials/preseed_key.html
.. _`read the source`: https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.sh
.. _`Salt`: https://saltstack.com/community/
.. _`Salt's Supported Operating Systems`: http://saltstack.com/wp-content/uploads/2016/08/SaltStack-Supported-Operating-Systems.pdf
.. _`SaltStack's corporate repository`: https://repo.saltstack.com/
.. _`SaltStack's Ubuntu repository`: http://repo.saltstack.com/#ubuntu
.. _Vagrant: http://www.vagrantup.com


.. |windows_build|  image:: https://ci.appveyor.com/api/projects/status/github/saltstack/salt-bootstrap?branch=develop&svg=true
    :target: https://ci.appveyor.com/project/saltstack-public/salt-bootstrap
    :alt: Build status of the develop branch on Windows

.. vim: fenc=utf-8 spell spl=en cc=100 tw=99 fo=want sts=2 sw=2 et
