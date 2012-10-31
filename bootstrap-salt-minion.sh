#!/bin/bash -
#===============================================================================
# vim: softtabstop=4 shiftwidth=4 expandtab fenc=utf-8 spell spelllang=en
#===============================================================================
#
#          FILE: bootstrap-salt-minion.sh
#
#   DESCRIPTION: Bootstrap salt installation for various systems/distributions
#
#          BUGS: https://github.com/saltstack/salty-vagrant/issues
#        AUTHOR: Pedro Algarvio (s0undt3ch), pedro@algarvio.me
#                Alec Koumjian (akoumjian)
#  ORGANIZATION: Salt Stack (saltstack.org)
#       CREATED: 10/15/2012 09:49:37 PM WEST
#===============================================================================
set -o nounset                              # Treat unset variables as an error
ScriptVersion="1.0"

#===============================================================================
#  LET THE BLACK MAGIC BEGIN!!!!
#===============================================================================

#===  FUNCTION  ================================================================
#         NAME:  usage
#  DESCRIPTION:  Display usage information.
#===============================================================================
usage() {
    cat << EOT

  Usage :  ${0##/*/} [options] <install-type> <install-type-args>

  Installation types:
    - stable (default)
    - daily  (ubuntu specific)
    - git

  Examples:
    $ ${0##/*/}
    $ ${0##/*/} stable
    $ ${0##/*/} daily
    $ ${0##/*/} git
    $ ${0##/*/} git develop
    $ ${0##/*/} git 8c3fadf15ec183e5ce8c63739850d543617e4357

  Options:
  -h|help       Display this message
  -v|version    Display script version
EOT
}   # ----------  end of function usage  ----------

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------

while getopts ":hv" opt
do
  case $opt in

    h|help     )  usage; exit 0   ;;

    v|version  )  echo "$0 -- Version $ScriptVersion"; exit 0   ;;

    \? )  echo "\n  Option does not exist : $OPTARG\n"
          usage; exit 1   ;;

  esac    # --- end of case ---
done
shift $(($OPTIND-1))

# Define installation type
if [ "$#" -eq 0 ];then
    ITYPE="stable"
else
    ITYPE=$1
    shift
fi

if [ "$ITYPE" != "stable" -a "$ITYPE" != "daily" -a "$ITYPE" != "git" ]; then
    echo " ERROR: Installation type \"$ITYPE\" is not known..."
    exit 1
fi

if [ $ITYPE = "git" ]; then
    if [ "$#" -eq 0 ];then
        GIT_REV="master"
    else
        GIT_REV=$1
        shift
    fi
fi

if [ "$#" -gt 0 ]; then
    usage
    echo
    echo " * ERROR: Too many arguments."
    exit 1
fi

# Root permissions are required to run this script
if [ $(whoami) != "root" ] ; then
    echo " * ERROR: Salt requires root privileges to install. Please re-run this script as root."
    exit 1
fi

# Define our logging file and pipe paths
LOGFILE="/tmp/$(basename $0 | sed s/.sh/.log/g )"
LOGPIPE="/tmp/$(basename $0 | sed s/.sh/.logpipe/g )"

# Create our logging pipe
mknod $LOGPIPE p

# What ever is written to the logpipe gets written to the logfile
tee < $LOGPIPE $LOGFILE &

# Close STDOUT, reopen it directing it to the logpipe
exec 1>&-
exec 1>$LOGPIPE
# Close STDERR, reopen it directing it to the logpipe
exec 2>&-
exec 2>$LOGPIPE

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __exit_cleanup
#   DESCRIPTION:  Cleanup any leftovers after script has ended
#-------------------------------------------------------------------------------
__exit_cleanup() {
    EXIT_CODE=$?

    # Remove the logging pipe when the script exits
    echo " * Removing the logging pipe $LOGPIPE"
    rm -f $LOGPIPE

    # Kill tee when exiting, CentOS, at least requires this
    TEE_PID=$(ps ax | grep tee | grep $LOGFILE | awk '{print $1}')
    echo " * Killing logging pipe tee's with pid(s): $TEE_PID"

    # We need to trap errors since killing tee will cause a 127 errno
    # We also do this as late as possible so we don't "mis-catch" other errors
    __trap_errors() {
        echo "Errors Trapped: $EXIT_CODE"
        # Exit with the "original" exit code, not the trapped code
        exit $EXIT_CODE
    }
    trap "__trap_errors" ERR

    # Now we're "good" to kill tee
    kill -TERM $TEE_PID

    # In case the 127 errno is not triggered, exit with the "original" exit code
    exit $EXIT_CODE
}
trap "__exit_cleanup" EXIT


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __gather_hardware_info
#   DESCRIPTION:  Discover hardware information
#-------------------------------------------------------------------------------
__gather_hardware_info() {
    CPU_VENDOR_ID=$(cat /proc/cpuinfo | grep vendor_id | head -n 1 | awk '{print $3}')
    CPU_VENDOR_ID_L=$( echo $CPU_VENDOR_ID | tr '[:upper:]' '[:lower:]' )
    CPU_ARCH=$(uname -m 2>/dev/null || uname -p 2>/dev/null || echo "unknown")
    CPU_ARCH_L=$( echo $CPU_ARCH | tr '[:upper:]' '[:lower:]' )

}
__gather_hardware_info


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __gather_os_info
#   DESCRIPTION:  Discover operating system information
#-------------------------------------------------------------------------------
__gather_os_info() {
    OS_NAME=$(uname -s 2>/dev/null)
    OS_NAME_L=$( echo $OS_NAME | tr '[:upper:]' '[:lower:]' )
    OS_VERSION=$(uname -r)
    OS_VERSION_L=$( echo $OS_VERSION | tr '[:upper:]' '[:lower:]' )
}
__gather_os_info


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __parse_version_string
#   DESCRIPTION:  Parse version strings ignoring the revision.
#                 MAJOR.MINOR.REVISION becomes MAJOR.MINOR
#-------------------------------------------------------------------------------
__parse_version_string() {
    VERSION_STRING="$1"
    PARSED_VERSION=$(
        echo $VERSION_STRING |
        sed -e 's/^/#/' \
            -e 's/^#[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\)\(\.[0-9][0-9]*\).*$/\1/' \
            -e 's/^#[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*$/\1/' \
            -e 's/^#[^0-9]*\([0-9][0-9]*\).*$/\1/' \
            -e 's/^#.*$//'
    )
    echo $PARSED_VERSION
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __gather_linux_system_info
#   DESCRIPTION:  Discover Linux system information
#-------------------------------------------------------------------------------
__gather_linux_system_info() {
    DISTRO_NAME=""
    DISTRO_VERSION=""

    if [ -f /etc/lsb-release ]; then
        DISTRO_NAME=$(grep DISTRIB_ID /etc/lsb-release | sed -e 's/.*=//')
        DISTRO_VERSION=$(__parse_version_string $(grep DISTRIB_RELEASE /etc/lsb-release | sed -e 's/.*=//'))
    fi

    if [ "x$DISTRO_NAME" != "x" -a "x$DISTRO_VERSION" != "x" ]; then
        # We already have the distribution name and version
        return
    fi

    for rsource in $(
            cd /etc && /bin/ls *[_-]release *[_-]version 2>/dev/null | env -i sort | \
            sed -e '/^redhat-release$/d' -e '/^lsb-release$/d'; \
            echo redhat-release lsb-release
            ); do

        [ ! -f "/etc/${rsource}" ] && continue

        n=$(echo ${rsource} | sed -e 's/[_-]release$//' -e 's/[_-]version$//')
        v=$(__parse_version_string "$((grep VERSION /etc/${rsource}; cat /etc/${rsource}) | grep '[0-9]' | sed -e 'q')")
        case $(echo ${n} | tr '[:upper:]' '[:lower:]') in
            redhat )
                if [ ".$(egrep '(Red Hat Enterprise Linux|CentOS)' /etc/${rsource})" != . ]; then
                    n="<R>ed <H>at <E>nterprise <L>inux"
                else
                    n="<R>ed <H>at <L>inux"
                fi
                ;;
            arch               ) n="Arch"           ;;
            centos             ) n="CentOS"         ;;
            debian             ) n="Debian"         ;;
            ubuntu             ) n="Ubuntu"         ;;
            fedora             ) n="Fedora"         ;;
            suse               ) n="SUSE"           ;;
            mandrake*|mandriva ) n="Mandriva"       ;;
            gentoo             ) n="Gentoo"         ;;
            slackware          ) n="Slackware"      ;;
            turbolinux         ) n="TurboLinux"     ;;
            unitedlinux        ) n="UnitedLinux"    ;;
            *                  ) n="${n}"           ;
        esac
        DISTRO_NAME=$n
        DISTRO_VERSION=$v
        break
    done
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __gather_sunos_system_info
#   DESCRIPTION:  Discover SunOS system info
#-------------------------------------------------------------------------------
__gather_sunos_system_info() {
    DISTRO_NAME="Solaris"
    DISTRO_VERSION=$(
        echo "${OS_VERSION}" |
        sed -e 's;^4\.;1.;' \
            -e 's;^5\.\([0-6]\)[^0-9]*$;2.\1;' \
            -e 's;^5\.\([0-9][0-9]*\).*;\1;'
    )
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __gather_bsd_system_info
#   DESCRIPTION:  Discover OpenBSD, NetBSD and FreeBSD systems information
#-------------------------------------------------------------------------------
__gather_bsd_system_info() {
    DISTRO_NAME=${OS_NAME}
    DISTRO_VERSION=$(echo "${OS_VERSION}" | sed -e 's;[()];;' -e 's/\(-.*\)$/[\1]/')
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __gather_system_info
#   DESCRIPTION:  Discover which system and distribution we are running.
#-------------------------------------------------------------------------------
__gather_system_info() {
    case ${OS_NAME_L} in
        linux )
            __gather_linux_system_info
            ;;
        sunos )
            __gather_sunos_system_info
            ;;
        openbsd|freebsd|netbsd )
            __gather_bsd_system_info
            ;;
        * )
            echo " * ERROR: $OS_NAME not supported.";
            exit 1
            ;;
    esac

}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __function_defined
#   DESCRIPTION:  Checks if a function is defined within this scripts scope
#    PARAMETERS:  function name
#       RETURNS:  0 or 1 as in defined or not defined
#-------------------------------------------------------------------------------
__function_defined() {
    FUNC_NAME=$1
    if [ ${DISTRO_NAME} = "centos" ]; then
        if typeset -f $FUNC_NAME &>/dev/null ; then
            echo " * INFO: Found function $FUNC_NAME"
            return 0
        fi
    elif [ ${DISTRO_NAME} = "ubuntu" ]; then
        if $( type ${FUNC_NAME} | grep -q 'shell function' ); then
            echo " * INFO: Found function $FUNC_NAME"
            return 0
        fi
    # Last resorts try POSIXLY_CORRECT or not
    elif test -n "${POSIXLY_CORRECT+yes}"; then
        if typeset -f $FUNC_NAME &>/dev/null ; then
            echo " * INFO: Found function $FUNC_NAME"
            return 0
        fi
    else
        # Arch linux seems to fall here
        if $( type ${FUNC_NAME}  &>/dev/null ) ; then
            echo " * INFO: Found function $FUNC_NAME"
            return 0
        fi
    fi
    echo " * INFO: $FUNC_NAME not found...."
    return 1
}
__gather_system_info


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __git_clone_and_checkout
#   DESCRIPTION:  (DRY) Helper function to clone and checkout salt to a
#                 specific revision.
#-------------------------------------------------------------------------------
__git_clone_and_checkout() {
    SALT_GIT_CHECKOUT_DIR=/tmp/git/salt
    [ -d /tmp/git ] || mkdir /tmp/git
    cd /tmp/git
    [ -d $SALT_GIT_CHECKOUT_DIR ] || git clone git://github.com/saltstack/salt.git salt
    cd salt
    git checkout $GIT_REV
}


echo " * System Information:"
echo "     CPU:          ${CPU_VENDOR_ID} ${CPU_ARCH}"
echo "     OS Name:      ${OS_NAME}"
echo "     OS Version:   ${OS_VERSION}"
echo "     Distribution: ${DISTRO_NAME} ${DISTRO_VERSION}"


# Simplify version naming on functions
if [ "x${DISTRO_VERSION}" = "x" ]; then
    DISTRO_VERSION_NO_DOTS=""
else
    DISTRO_VERSION_NO_DOTS="_$(echo $DISTRO_VERSION | tr -d '.')"
fi
# Simplify distro name naming on functions
DISTRO_NAME_L=$(echo $DISTRO_NAME | tr '[:upper:]' '[:lower:]')

##############################################################################
#
#   Distribution install functions
#
#   In order to install salt for a distribution you need to define:
#
#   To Install Dependencies, which is required, one of:
#       1. install_<distro>_<distro_version>_<install_type>_deps
#       2. install_<distro>_<distro_version>_deps
#       3. install_<distro>_<install_type>_deps
#       4. install_<distro>_deps
#
#
#   To install salt, which, of course, is required, one of:
#       1. install_<distro>_<distro_version>_<install_type>
#       1. install_<distro>_<install_type>
#
#
#   And optionally, define a post install function, one of:
#       1. install_<distro>_<distro_versions>_<install_type>_post
#       2. install_<distro>_<distro_versions>_post
#       3. install_<distro>_<install_type>_post
#       4. install_<distro>_post
#
##############################################################################

##############################################################################
#
#   Ubuntu Install Functions
#
install_ubuntu_deps() {
    apt-get update
    apt-get -y install python-software-properties
    add-apt-repository -y ppa:saltstack/salt
    apt-get update
}

install_ubuntu_1004_deps() {
    apt-get update
    apt-get -y install python-software-properties
    add-apt-repository ppa:saltstack/salt
    apt-get update
    apt-get -y install salt-minion
}

install_ubuntu_1004_git_deps() {
    install_ubuntu_1004_deps
    apt-get -y install git-core
}

install_ubuntu_1110_deps() {
    apt-get update
    apt-get -y install python-software-properties
    add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
    add-apt-repository -y ppa:saltstack/salt
}

install_ubuntu_daily_deps() {
    apt-get update
    apt-get -y install python-software-properties
    add-apt-repository -y ppa:saltstack/salt-daily
    apt-get update
}

install_ubuntu_git_deps() {
    apt-get update
    apt-get install -y python-software-properties
    add-apt-repository  ppa:saltstack/salt
    apt-get update
    apt-get install -y git-core python-yaml python-m2crypto python-crypto msgpack-python python-zmq python-jinja2
}

install_ubuntu_1110_post() {
    add-apt-repository -y --remove 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
}

install_ubuntu_stable() {
    apt-get -y install salt-minion
}

install_ubuntu_daily() {
    apt-get -y install salt-minion
}

install_ubuntu_git() {
    __git_clone_and_checkout
    python setup.py install --install-layout=deb
}

install_ubuntu_git_post() {
    for fname in $(echo "minion master syndic"); do
        if [ $fname != "minion" ]; then
            # Guess we should only enable and start the minion service. Right??
            continue
        fi
        cp ${SALT_GIT_CHECKOUT_DIR}/debian/salt-$fname.init /etc/init.d/salt-$fname
        cp ${SALT_GIT_CHECKOUT_DIR}/debian/salt-$fname.upstart /etc/init/salt-$fname.conf
        chmod +x /etc/init.d/salt-$fname
        service salt-$fname start
    done
}
#
#   End of Ubuntu Install Functions
#
##############################################################################

##############################################################################
#
#   Debian Install Functions
#
install_debian_60_stable_deps() {
    echo "deb http://backports.debian.org/debian-backports squeeze-backports main" >> \
        /etc/apt/sources.list.d/backports.list
    apt-get update
}

install_debian_60_stable() {
    apt-get -t squeeze-backports -y install salt-minion
}

install_debian_60_git_deps() {
    install_debian_60_stable_deps
    install_debian_60_stable
}

install_debian_60_git() {
    apt-get -y install git
    apt-get -y purge salt-minion

    __git_clone_and_checkout

    python setup.py install --install-layout=deb
    mkdir -p /etc/salt
    cp conf/minion.template /etc/salt/minion
}
#
#   Ended Debian Install Functions
#
##############################################################################

##############################################################################
#
#   Fedora Install Functions
#
install_fedora_deps() {
    yum install -y PyYAML libyaml m2crypto python-crypto python-jinja2 python-msgpack python-zmq
}

install_fedora_stable() {
    yum install -y salt-minion
}


install_fedora_git_deps() {
    install_fedora_deps
    yum install -y git
}

install_fedora_git() {
    __git_clone_and_checkout
    python setup.py install
}

install_fedora_git_post() {
    for fname in $(echo "minion master syndic"); do
        if [ $fname != "minion" ]; then
            # Guess we should only enable and start the minion service. Right??
            continue
        fi
        #cp ${SALT_GIT_CHECKOUT_DIR}/pkg/rpm/salt-$fname /etc/rc.d/init.d/salt-$fname
        cp ${SALT_GIT_CHECKOUT_DIR}/pkg/rpm/salt-$fname.service /lib/systemd/system/salt-$fname.service
        #chmod +x /etc/rc.d/init.d/salt-$fname

        # Switch from forking to simple, dunny why I can't make it work
        sed -i 's/Type=forking/Type=simple/g' /lib/systemd/system/salt-$fname.service
        # Remove the daemon flag because of the above
        sed -ie 's;ExecStart=\(.*\) -d;ExecStart=\1;' /lib/systemd/system/salt-$fname.service
        systemctl preset salt-$fname.service
        systemctl enable salt-$fname.service
        sleep 0.2
        systemctl daemon-reload
        sleep 0.2
        systemctl start salt-$fname.service
    done
}
#
#   Ended Fedora Install Functions
#
##############################################################################

##############################################################################
#
#   CentOS Install Functions
#
install_centos_63_stable_deps() {
    if [ $CPU_ARCH_L = "i686" ]; then
        local ARCH="i386"
    else
        local ARCH=$CPU_ARCH_L
    fi
    rpm -Uvh --force http://mirrors.kernel.org/fedora-epel/6/${ARCH}/epel-release-6-7.noarch.rpm
    yum -y update
}

install_centos_63_stable() {
    yum -y install salt-minion --enablerepo=epel-testing
}

install_centos_63_stable_post() {
    /sbin/chkconfig salt-minion on
    /etc/init.d/salt-minion start
}

install_centos_63_git_deps() {
    install_centos_63_stable_deps
    yum -y install git PyYAML m2crypto python-crypto python-msgpack python-zmq python-jinja2 --enablerepo=epel-testing
}

install_centos_63_git() {
    rm -rf /usr/lib/python*/site-packages/salt
    rm -rf /usr/bin/salt*

    __git_clone_and_checkout
    python2 setup.py install
    mkdir -p /etc/salt/
}

install_centos_63_git_post() {
    cp pkg/rpm/salt-{master,minion} /etc/init.d/
    chmod +x /etc/init.d/salt-{master,minion}
    /sbin/chkconfig salt-minion on
    /etc/init.d/salt-minion start
}
#
#   Ended CentOS Install Functions
#
##############################################################################


##############################################################################
#
#   Arch Install Functions
#
install_arch_stable_deps() {
    echo '[salt]
Server = http://red45.org/archlinux
' >> /etc/pacman.conf
}

install_arch_git_deps() {
    echo '[salt]
    Server = http://red45.org/archlinux
    ' >> /etc/pacman.conf
}

install_arch_stable() {
    pacman -Sy --noconfirm pacman
    pacman -Syu --noconfirm salt
}

install_arch_git() {
    pacman -Sy --noconfirm pacman
    pacman -Syu --noconfirm salt git
    rm -rf /usr/lib/python2.7/site-packages/salt*
    rm -rf /usr/bin/salt-*

    __git_clone_and_checkout

    python2 setup.py install
}

install_arch_post() {
    /etc/rc.d/salt-minion start
}
#
#   Ended Arch Install Functions
#
##############################################################################

##############################################################################
#
#   FreeBSD Install Functions
#
install_freebsd_9_stable_deps() {
    if [ $CPU_VENDOR_ID_L = "AuthenticAMD" -a $CPU_ARCH_L = "x86_64" ]; then
        local ARCH="amd64"
    elif [ $CPU_VENDOR_ID_L = "GenuineIntel" -a $CPU_ARCH_L = "x86_64" ]; then
        local ARCH="x86:64"
    elif [ $CPU_VENDOR_ID_L = "GenuineIntel" -a $CPU_ARCH_L = "i386" ]; then
        local ARCH="i386"
    elif [ $CPU_VENDOR_ID_L = "GenuineIntel" -a $CPU_ARCH_L = "i686" ]; then
        local ARCH="x86:32"
    fi

    portsnap fetch extract update
    cd /usr/ports/ports-mgmt/pkg
    make install clean
    cd
    /usr/local/sbin/pkg2ng
    echo 'PACKAGESITE: http://pkgbeta.freebsd.org/freebsd-9-${ARCH}/latest' > /usr/local/etc/pkg.conf
}

install_freebsd_git_deps() {
    if [ $CPU_VENDOR_ID_L = "AuthenticAMD" -a $CPU_ARCH_L = "x86_64" ]; then
        local ARCH="amd64"
    elif [ $CPU_VENDOR_ID_L = "GenuineIntel" -a $CPU_ARCH_L = "x86_64" ]; then
        local ARCH="x86:64"
    elif [ $CPU_VENDOR_ID_L = "GenuineIntel" -a $CPU_ARCH_L = "i386" ]; then
        local ARCH="i386"
    elif [ $CPU_VENDOR_ID_L = "GenuineIntel" -a $CPU_ARCH_L = "i686" ]; then
        local ARCH="x86:32"
    fi

    portsnap fetch extract update
    cd /usr/ports/ports-mgmt/pkg
    make install clean
    cd
    /usr/local/sbin/pkg2ng
    echo 'PACKAGESITE: http://pkgbeta.freebsd.org/freebsd-9-${ARCH}/latest' > /usr/local/etc/pkg.conf
}

install_freebsd_9_stable() {
    pkg install -y salt
}

install_freebsd_git() {
    /usr/local/sbin/pkg install -y git salt
    /usr/local/sbin/pkg delete -y salt

    __git_clone_and_checkout

    /usr/local/bin/python setup.py install
}

install_freebsd_9_stable_post() {
    salt-minion -d
}

install_freebsd_git_post() {
    salt-minion -d
}
#
#   Ended FreeBSD Install Functions
#
##############################################################################


#=============================================================================
# LET'S PROCEED WITH OUR INSTALLATION
#=============================================================================
# Let's get the dependencies install function
DEP_FUNC_NAMES="install_${DISTRO_NAME_L}${DISTRO_VERSION_NO_DOTS}_${ITYPE}_deps"
DEP_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}${DISTRO_VERSION_NO_DOTS}_deps"
DEP_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}_${ITYPE}_deps"
DEP_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}_deps"

DEPS_INSTALL_FUNC="null"
for DEP_FUNC_NAME in $DEP_FUNC_NAMES; do
    if __function_defined $DEP_FUNC_NAME; then
        DEPS_INSTALL_FUNC=$DEP_FUNC_NAME
        break
    fi
done


# Let's get the install function
INSTALL_FUNC_NAMES="install_${DISTRO_NAME_L}${DISTRO_VERSION_NO_DOTS}_${ITYPE}"
INSTALL_FUNC_NAMES="$INSTALL_FUNC_NAMES install_${DISTRO_NAME_L}_${ITYPE}"

INSTALL_FUNC="null"
for FUNC_NAME in $INSTALL_FUNC_NAMES; do
    if __function_defined $FUNC_NAME; then
        INSTALL_FUNC=$FUNC_NAME
        break
    fi
done


# Let's get the dependencies install function
POST_FUNC_NAMES="install_${DISTRO_NAME_L}${DISTRO_VERSION_NO_DOTS}_${ITYPE}_post"
POST_FUNC_NAMES="$POST_FUNC_NAMES install_${DISTRO_NAME_L}${DISTRO_VERSION_NO_DOTS}_post"
POST_FUNC_NAMES="$POST_FUNC_NAMES install_${DISTRO_NAME_L}_${ITYPE}_post"
POST_FUNC_NAMES="$POST_FUNC_NAMES install_${DISTRO_NAME_L}_post"

POST_INSTALL_FUNC="null"
for FUNC_NAME in $POST_FUNC_NAMES; do
    if __function_defined $FUNC_NAME; then
        POST_INSTALL_FUNC=$FUNC_NAME
        break
    fi
done


if [ $DEPS_INSTALL_FUNC = "null" ]; then
    echo " * ERROR: No dependencies installation function found. Exiting..."
    exit 1
fi

if [ $DEPS_INSTALL_FUNC = "null" ]; then
    echo " * ERROR: No installation function found. Exiting..."
    exit 1
fi


# Install dependencies
echo " * Running ${DEPS_INSTALL_FUNC}()"
$DEPS_INSTALL_FUNC
if [ $? -ne 0 ]; then
    echo " * Failed to run ${DEPS_INSTALL_FUNC}()!!!"
    exit 1
fi

# Install Salt
echo " * Running ${INSTALL_FUNC}()"
$INSTALL_FUNC
if [ $? -ne 0 ]; then
    echo " * Failed to run ${INSTALL_FUNC}()!!!"
    exit 1
fi

# Run any post install function
if [ "$POST_INSTALL_FUNC" != "null" ]; then
    echo " * Running ${POST_INSTALL_FUNC}()"
    $POST_INSTALL_FUNC
    if [ $? -ne 0 ]; then
        echo " * Failed to run ${POST_INSTALL_FUNC}()!!!"
        exit 1
    fi
fi

# Done!
echo " * Salt installed!"
exit 0
