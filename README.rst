Bootstrapping Salt
==================

Before `Salt`_ can be used for provisioning on the desired machine, the 
binaries need to be installed. Since `Salt`_ supports many different 
distributions and versions of operating systems, the `Salt`_ installation 
process is handled by this shell script ``bootstrap-salt-minion.sh``.  This 
script runs through a series of checks to determine operating system type and 
version to then install the `Salt`_ binaries using the appropriate methods.

Adding support for other operating systems
------------------------------------------
In order to install salt for a distribution you need to define:

* To Install Dependencies, which is required, one of:
  1. ``install_<distro>_<distro_version>_<install_type>_deps``
  2. ``install_<distro>_<distro_version>_deps``
  3. ``install_<distro>_<install_type>_deps``
  4. ``install_<distro>_deps``


* To install salt, which, of course, is required, one of:
  1. ``install_<distro>_<distro_version>_<install_type>``
  2. ``install_<distro>_<install_type>``

   Optionally, define a minion configuration function, which will be called if
   the -c|config-dir option is passed. One of:
       1. config_<distro>_<distro_version>_<install_type>_minion
       2. config_<distro>_<distro_version>_minion
       3. config_<distro>_<install_type>_minion
       4. config_<distro>_minion
       5. config_minion [THIS ONE IS ALREADY DEFINED AS THE DEFAULT]

   Also optionally, define a post install function, one of:
       1. install_<distro>_<distro_versions>_<install_type>_post
       2. install_<distro>_<distro_versions>_post
       3. install_<distro>_<install_type>_post
       4. install_<distro>_post

Below is an example for Ubuntu Oneiric:

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
- CentOS 6.3
- Fedora
- Arch
- FreeBSD 9.0


One Line Bootstrap
------------------

Salt can be installed using a single line command.
For example, using ``curl`` to install latest git::

  curl -L http://bootstrap.saltstack.org | sudo sh -s git develop


Or, using ``wget`` to install current distro's stable version::

  wget -O - http://bootstrap.saltstack.org | sudo sh

If you have certificate issues using ``wget`` try the following::

  wget --no-check-certificate -O - http://bootstrap.saltstack.org | sudo sh


.. _`Salt`: http://saltstack.org/
.. vim: fenc=utf-8 spell spl=en cc=80 tw=79 fo=want sts=2 sw=2 et
