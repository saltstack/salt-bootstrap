==================
Bootstrapping Salt
==================

.. image:: https://secure.travis-ci.org/saltstack/salt-bootstrap.png?branch=develop
   :target: http://travis-ci.org/saltstack/salt-bootstrap

Before `Salt`_ can be used for provisioning on the desired machine, the 
binaries need to be installed. Since `Salt`_ supports many different 
distributions and versions of operating systems, the `Salt`_ installation 
process is handled by this shell script ``bootstrap-salt-minion.sh``.  This 
script runs through a series of checks to determine operating system type and 
version to then install the `Salt`_ binaries using the appropriate methods.


One Line Bootstrap
------------------

If you're looking for the *one-liner* to install salt...

For example, using ``curl`` to install latest git:

.. code:: console

  curl -L http://bootstrap.saltstack.org | sudo sh -s -- git develop



Or, using ``wget`` to install your distribution's stable packages:

.. code:: console

  wget -O - http://bootstrap.saltstack.org | sudo sh


If you have certificate issues using ``wget`` try the following:

.. code:: console

  wget --no-check-certificate -O - http://bootstrap.saltstack.org | sudo sh



If you already have python installed, then it's as easy as:

.. code:: console

  python -m urllib "http://bootstrap.saltstack.org" | sudo sh -s -- git develop


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

  install_<distro>_<distro_version>_<install_type>_deps
  install_<distro>_<distro_version>_deps
  install_<distro>_<install_type>_deps
  install_<distro>_deps


2. Optionally, define a minion configuration function, which will be called if the 
   ``-c|config-dir`` option is passed. One of:

.. code:: bash

  config_<distro>_<distro_version>_<install_type>_minion
  config_<distro>_<distro_version>_minion
  config_<distro>_<install_type>_minion
  config_<distro>_minion
  config_minion [THIS ONE IS ALREADY DEFINED AS THE DEFAULT]


3. To install salt, which, of course, is required, one of:

.. code:: bash

  install_<distro>_<distro_version>_<install_type>
  install_<distro>_<install_type>


4. Also optionally, define a post install function, one of:

.. code:: bash

  install_<distro>_<distro_versions>_<install_type>_post
  install_<distro>_<distro_versions>_post
  install_<distro>_<install_type>_post
  install_<distro>_post


Below is an example for Ubuntu Oneiric:

.. code:: bash

  install_ubuntu_1110_deps() {
      apt-get update
      apt-get -y install python-software-properties
      add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
      add-apt-repository -y ppa:saltstack/salt
  }

  install_ubuntu_1110_post() {
      add-apt-repository -y --remove 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
  }

  install_ubuntu_stable() {
      apt-get -y install salt-minion
  }


Since there is no ``install_ubuntu_1110_stable()`` it defaults to the 
unspecified version script.

The bootstrapping script must be plain POSIX sh only, **not** bash or another 
shell script. By design the targeting for each operating system and version is 
very specific. Assumptions of supported versions or variants should not be 
made, to avoid failed or broken installations.

Supported Operating Systems
---------------------------
- Ubuntu 10.x/11.x/12.x
- Debian 6.x
- CentOS 5/6
- Red Hat 5/6
- Red Hat Enterprise 5/6
- Fedora
- Arch
- FreeBSD 9.0
- SmartOS



.. _`Salt`: http://saltstack.org/
.. vim: fenc=utf-8 spell spl=en cc=100 tw=99 fo=want sts=2 sw=2 et
