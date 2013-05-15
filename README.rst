==================
Bootstrapping Salt
==================

Before `Salt`_ can be used for provisioning on the desired machine, the binaries need to be 
installed. Since `Salt`_ supports many different distributions and versions of operating systems, 
the `Salt`_ installation process is handled by this shell script ``bootstrap-salt.sh``.  This 
script runs through a series of checks to determine operating system type and version to then 
install the `Salt`_ binaries using the appropriate methods.


One Line Bootstrap
------------------

If you're looking for the *one-liner* to install salt...

For example, using ``curl`` to install latest git:

.. code:: console

  curl -L http://bootstrap.saltstack.org | sudo sh -s -- git develop


If you have certificate issues using ``curl``, try the following:

.. code:: console 

  curl --insecure -L http://bootstrap.saltstack.org | sudo sh -s -- git develop



Using ``wget`` to install your distribution's stable packages:

.. code:: console

  wget -O - http://bootstrap.saltstack.org | sudo sh


If you have certificate issues using ``wget`` try the following:

.. code:: console

  wget --no-check-certificate -O - http://bootstrap.saltstack.org | sudo sh



If you already have python installed, ``python 2.6``, then it's as easy as:

.. code:: console

  python -m urllib "http://bootstrap.saltstack.org" | sudo sh -s -- git develop


All python versions should support the following one liner:

.. code:: console

  python -c 'import urllib; print urllib.urlopen("http://bootstrap.saltstack.org").read()' | \
  sudo  sh -s -- git develop


On a FreeBSD base system you usually don't have either of the above binaries available. You **do** 
have ``fetch`` available though:

.. code:: console

  fetch -o - http://bootstrap.saltstack.org | sudo sh



If all you want is to install a ``salt-master`` using latest git:

.. code:: console

  curl -L http://bootstrap.saltstack.org | sudo sh -s -- -M -N git develop



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

  pressed_<distro>_<major_version>_<install_type>_master
  pressed_<distro>_<major_version>_<minor_version>_<install_type>_master
  pressed_<distro>_<major_version>_master
  pressed_<distro>_<major_version>_<minor_version>_master
  pressed_<distro>_<install_type>_master
  pressed_<distro>_master
  pressed_master [THIS ONE IS ALREADY DEFINED AS THE DEFAULT]


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


----

Below is an example for Ubuntu Oneiric:

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
          /etc/init.d/salt-$fname start &
      done
  }


Since there is no ``install_ubuntu_11_10_stable()`` it defaults to the unspecified version script.

The bootstrapping script must be plain POSIX sh only, **not** bash or another shell script. By 
design the targeting for each operating system and version is very specific. Assumptions of 
supported versions or variants should not be made, to avoid failed or broken installations.

Supported Operating Systems
---------------------------
- Ubuntu 10.x/11.x/12.x/13.04
- Debian 6.x/7.x
- CentOS 5/6
- Red Hat 5/6
- Red Hat Enterprise 5/6
- Fedora
- Arch
- FreeBSD 9.0
- SmartOS
- SuSE 11 SP1/11 SP2
- OpenSUSE 12.x



.. _`Salt`: http://saltstack.org/
.. vim: fenc=utf-8 spell spl=en cc=100 tw=99 fo=want sts=2 sw=2 et
