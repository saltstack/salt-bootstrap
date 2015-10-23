==================
Bootstrapping Salt
==================

Before `Salt`_ can be used for provisioning on the desired machine, the binaries need to be 
installed. Since `Salt`_ supports many different distributions and versions of operating systems, 
the `Salt`_ installation process is handled by this shell script ``bootstrap-salt.sh``.  This 
script runs through a series of checks to determine operating system type and version to then 
install the `Salt`_ binaries using the appropriate methods.


.. note::

  This ``README`` file is not the absolute truth to what the bootstrap script is capable of, for 
  that, please read the generated help by passing ``-h`` to the script or even better, `read the 
  source`_.


.. _`read the source`: https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.sh


**In case you found a bug, please read** `I found a bug`_ **first before submitting a new issue.**



Bootstrap
---------

If you're looking for the *one-liner* to install salt, please scroll to the bottom and use the
instructions for `Installing via an Insecure One-Liner`_.


Examples
~~~~~~~~

.. note::

    In every two-step example, you would be well-served to examine the downloaded file and examine
    it to ensure that it does what you expect.


Using ``curl`` to install latest git:

.. code:: console

  curl -L https://bootstrap.saltstack.com -o install_salt.sh
  sudo sh install_salt.sh git develop


Using ``wget`` to install your distribution's stable packages:

.. code:: console

  wget -O install_salt.sh https://bootstrap.saltstack.com
  sudo sh install_salt.sh


Install a specific version from git using ``wget``:

.. code:: console

  wget -O install_salt.sh https://bootstrap.saltstack.com
  sudo sh install_salt.sh -P git v0.16.4

On the above example we added `-P` which will allow PIP packages to be installed if required but 
it's no a necessary flag for git based bootstraps.


If you already have python installed, ``python 2.6``, then it's as easy as:

.. code:: console

  python -m urllib "https://bootstrap.saltstack.com" > install_salt.sh
  sudo sh install_salt.sh git develop


All python versions should support the following one liner:

.. code:: console

  python -c 'import urllib; print urllib.urlopen("https://bootstrap.saltstack.com").read()' > install_salt.sh
  sudo sh install_salt.sh git develop


On a FreeBSD base system you usually don't have either of the above binaries available. You **do** 
have ``fetch`` available though:

.. code:: console

  fetch -o install_salt.sh https://bootstrap.saltstack.com
  sudo sh install_salt.sh

If you have any SSL issues install ``ca_root_nssp``:

.. code:: console

   pkg install ca_root_nssp

And either copy the certificates to the place where fetch can find them:

.. code:: console

   cp /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem

Or link them to the right place:

.. code:: console

   ln -s /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem


If all you want is to install a ``salt-master`` using latest git:

.. code:: console

  curl -o install_salt.sh -L https://bootstrap.saltstack.com
  sudo sh install_salt.sh -M -N git develop


If you want to install a specific release version (based on the git tags):

.. code:: console

  curl -o install_salt.sh -L https://bootstrap.saltstack.com
  sudo sh install_salt.sh git v0.16.4


To install a specific branch from a git fork:

.. code:: console

  curl -o install_salt.sh -L https://bootstrap.saltstack.com
  sudo sh install_salt.sh -g https://github.com/myuser/salt.git git mybranch


Any of the example above which use two-lines can be made to run in a single-line
configuration with minor modifications, see `Installing via an Insecure One-Liner`_.


Installing via an Insecure One-Liner
------------------------------------

The following examples illustrate how to install Salt via a one-liner.

.. note::

    Warning! These methods do not involve a verification step and assume that the delivered file
    is trustworthy.


Examples
~~~~~~~~

Installing the latest stable release of Salt (default):

.. code:: console

  curl -L https://bootstrap.saltstack.com | sudo sh -s -- stable

or

.. code:: console

  curl -L https://bootstrap.saltstack.com | sudo sh -s

Installing the latest develop branch of Salt:

.. code:: console

  curl -L https://bootstrap.saltstack.com | sudo sh -s -- git develop


Adding support for other operating systems
------------------------------------------
In order to install salt for a distribution you need to define:

1. To Install Dependencies, which is required, one of:

.. code:: bash

  install_<distro>_<major_version>_<install_type>_deps
  install_<distro>_<major_version>_<minor_version>_<install_type>_deps
  install_<distro>_<major_version>_deps
  install_<distro>_<major_version>_<minor_version>_deps
  install_<distro>_<install_type>_deps
  install_<distro>_deps


2. Optionally, define a minion configuration function, which will be called if the 
   ``-c|config-dir`` option is passed. One of:

.. code:: bash

  config_<distro>_<major_version>_<install_type>_salt
  config_<distro>_<major_version>_<minor_version>_<install_type>_salt
  config_<distro>_<major_version>_salt
  config_<distro>_<major_version>_<minor_version>_salt
  config_<distro>_<install_type>_salt
  config_<distro>_salt
  config_salt [THIS ONE IS ALREADY DEFINED AS THE DEFAULT]


3. Optionally, define a salt master pre-seed function, which will be called if the -k (pre-seed 
   master keys) option is passed. One of:

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

Below is an example for Ubuntu Oneiric(the example may not be up to date with the script):

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

The bootstrapping script must be plain POSIX sh only, **not** bash or another shell script. By 
design the targeting for each operating system and version is very specific. Assumptions of 
supported versions or variants should not be made, to avoid failed or broken installations.

Supported Operating Systems
---------------------------
- Amazon Linux 2012.09
- Arch
- CentOS 5/6/7
- Debian 6/7/8
- Fedora 17/18/20/21/22
- FreeBSD 9.1/9.2/10/11
- Gentoo
- Linaro
- Linux Mint 13/14
- OpenSUSE 12/13
- Oracle Linux 5/5
- Red Hat 5/6
- Red Hat Enterprise 5/6
- Scientific Linux 5/6
- SmartOS
- SUSE Linux Enterprise 11 SP1/11 SP2/11 SP3
- Ubuntu 10.x/11.x/12.x/13.x/14.x/15.04
- Elementary OS 0.2



I found a bug
-------------

If you found a possible problem, or bug, please try to bootstrap using the develop version. The 
issue you are having might have already been fixed and it's just not yet included in the stable 
version.

.. code:: console

  curl -o install_salt.sh -L https://bootstrap.saltstack.com/develop
  sudo sh install_salt.sh git develop


Or the insecure one liner:

.. code:: console

  curl -L https://bootstrap.saltstack.com/develop | sudo sh -s -- git develop


If after trying this, you still see the same problems, then, please `file an issue`_.



.. _`Salt`: http://saltstack.org/
.. _`file an issue`: https://github.com/saltstack/salt-bootstrap/issues/new


Unsupported Distro
------------------

You found a Linux distribution which we still do not support or we do not correctly identify?
Please run the following commands and report their output when creating a ticket:

.. code:: console

  sudo find /etc/ -name '*-release' -print -exec cat {} \;
  which lsb_release && lsb_release -a


Testing in Vagrant
------------------
You can use Vagrant_ to easily test changes on a clean machine. The ``Vagrantfile`` defaults to an 
Ubuntu box. First, install Vagrant, then:

.. code:: console

    $ vagrant up
    $ vagrant ssh


.. _Vagrant: http://www.vagrantup.com
.. _Installing via an Insecure One-Liner: #installing-via-an-insecure-one-liner
.. vim: fenc=utf-8 spell spl=en cc=100 tw=99 fo=want sts=2 sw=2 et
