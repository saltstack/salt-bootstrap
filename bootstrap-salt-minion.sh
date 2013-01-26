#!/bin/sh -
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
#                Alec Koumjian (akoumjian), akoumjian@gmail.com
#       LICENSE: Apache 2.0
#  ORGANIZATION: Salt Stack (saltstack.org)
#       CREATED: 10/15/2012 09:49:37 PM WEST
#===============================================================================
set -o nounset                              # Treat unset variables as an error
ScriptVersion="1.3"
ScriptName="bootstrap-salt-minion.sh"

#===============================================================================
#  LET THE BLACK MAGIC BEGIN!!!!
#===============================================================================

#===  FUNCTION  ================================================================
#         NAME:  usage
#  DESCRIPTION:  Display usage information.
#===============================================================================
usage() {
    cat << EOT

  Usage :  ${ScriptName} [options] <install-type> <install-type-args>

  Installation types:
    - stable (default)
    - daily  (ubuntu specific)
    - git

  Examples:
    $ ${ScriptName}
    $ ${ScriptName} stable
    $ ${ScriptName} daily
    $ ${ScriptName} git
    $ ${ScriptName} git develop
    $ ${ScriptName} git 8c3fadf15ec183e5ce8c63739850d543617e4357

  Options:
  -h  Display this message
  -v  Display script version
  -c  Temporary minion configuration directory
  -M  Also install salt-master
  -S  Also install salt-syndic
  -N  Do not install salt-minion
EOT
}   # ----------  end of function usage  ----------

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------
TEMP_CONFIG_DIR="null"
INSTALL_MASTER=0
INSTALL_SYNDIC=0
INSTALL_MINION=1

while getopts ":hvc:MSN" opt
do
  case "${opt}" in

    h )  usage; exit 0   ;;

    v )  echo "$0 -- Version $ScriptVersion"; exit 0   ;;
    c )  TEMP_CONFIG_DIR="$OPTARG" ;;
    M )  INSTALL_MASTER=1 ;;
    S )  INSTALL_SYNDIC=1 ;;
    N )  INSTALL_MINION=0 ;;

    \?)  echo
         echo "  Option does not exist : $OPTARG"
         usage
         exit 1
         ;;

  esac    # --- end of case ---
done
shift $(($OPTIND-1))

__check_unparsed_options() {
    shellopts="$1"
    unparsed_options=$( echo "$shellopts" | grep -E '[-]+[[:alnum:]]' )
    if [ "x$unparsed_options" != "x" ]; then
        usage
        echo
        echo " * ERROR: options come before install arguments"
        echo
        exit 1
    fi
}

# Check that we're actually installing one of minion/master/syndic
if [ $INSTALL_MINION -eq 0 ] && [ $INSTALL_MASTER -eq 0 ] && [ $INSTALL_SYNDIC -eq 0 ]; then
    echo " * ERROR: Nothing to install"
    exit 1
fi

# Define installation type
if [ "$#" -eq 0 ];then
    ITYPE="stable"
else
    __check_unparsed_options "$*"
    ITYPE=$1
    shift
fi

# Check installation type
if [ "$ITYPE" != "stable" ] && [ "$ITYPE" != "daily" ] && [ "$ITYPE" != "git" ]; then
    echo " ERROR: Installation type \"$ITYPE\" is not known..."
    exit 1
fi

# If doing a git install, check what branch/tag/sha will be checked out
if [ $ITYPE = "git" ]; then
    if [ "$#" -eq 0 ];then
        GIT_REV="master"
    else
        __check_unparsed_options "$*"
        GIT_REV="$1"
        shift
    fi
fi

# Check for any unparsed arguments. Should be an error.
if [ "$#" -gt 0 ]; then
    __check_unparsed_options "$*"
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

CALLER=$(echo `ps a -o pid,command | grep $$ | grep -v grep | tr -s ' '` | cut -d ' ' -f 2)
if [ "${CALLER}x" = "${0}x" ]; then
    CALLER="PIPED THROUGH"
fi
echo " * INFO: ${CALLER} $0 -- Version ${ScriptVersion}"
#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __exit_cleanup
#   DESCRIPTION:  Cleanup any leftovers after script has ended
#
#
#   http://www.unix.com/man-page/POSIX/1posix/trap/
#
#               Signal Number   Signal Name
#               1               SIGHUP
#               2               SIGINT
#               3               SIGQUIT
#               6               SIGABRT
#               9               SIGKILL
#              14               SIGALRM
#              15               SIGTERM
#-------------------------------------------------------------------------------
__exit_cleanup() {
    EXIT_CODE=$?

    # Remove the logging pipe when the script exits
    echo " * Removing the logging pipe $LOGPIPE"
    rm -f $LOGPIPE

    # Kill tee when exiting, CentOS, at least requires this
    TEE_PID=$(ps ax | grep tee | grep $LOGFILE | awk '{print $1}')

    [ "x$TEE_PID" = "x" ] && exit $EXIT_CODE

    echo " * Killing logging pipe tee's with pid(s): $TEE_PID"

    # We need to trap errors since killing tee will cause a 127 errno
    # We also do this as late as possible so we don't "mis-catch" other errors
    __trap_errors() {
        echo "Errors Trapped: $EXIT_CODE"
        # Exit with the "original" exit code, not the trapped code
        exit $EXIT_CODE
    }
    trap "__trap_errors" INT QUIT ABRT KILL QUIT TERM

    # Now we're "good" to kill tee
    kill -s TERM $TEE_PID

    # In case the 127 errno is not triggered, exit with the "original" exit code
    exit $EXIT_CODE
}
trap "__exit_cleanup" EXIT INT


# Define our logging file and pipe paths
LOGFILE="/tmp/$( echo $ScriptName | sed s/.sh/.log/g )"
LOGPIPE="/tmp/$( echo $ScriptName | sed s/.sh/.logpipe/g )"

# Create our logging pipe
# On FreeBSD we have to use mkfifo instead of mknod
mknod $LOGPIPE p >/dev/null 2>&1 || mkfifo $LOGPIPE >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo " * Failed to create the named pipe required to log"
    exit 1
fi

# What ever is written to the logpipe gets written to the logfile
tee < $LOGPIPE $LOGFILE &

# Close STDOUT, reopen it directing it to the logpipe
exec 1>&-
exec 1>$LOGPIPE
# Close STDERR, reopen it directing it to the logpipe
exec 2>&-
exec 2>$LOGPIPE


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __gather_hardware_info
#   DESCRIPTION:  Discover hardware information
#-------------------------------------------------------------------------------
__gather_hardware_info() {
    if [ -f /proc/cpuinfo ]; then
        CPU_VENDOR_ID=$(cat /proc/cpuinfo | grep -E 'vendor_id|Processor' | head -n 1 | awk '{print $3}' | cut -d '-' -f1 )
    else
        CPU_VENDOR_ID=$( sysctl -n hw.model )
    fi
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

    if [ "x$DISTRO_NAME" != "x" ] && [ "x$DISTRO_VERSION" != "x" ]; then
        # We already have the distribution name and version
        return
    fi

    for rsource in $(
            cd /etc && /bin/ls *[_-]release *[_-]version 2>/dev/null | env -i sort | \
            sed -e '/^redhat-release$/d' -e '/^lsb-release$/d'; \
            echo redhat-release lsb-release
            ); do

        [ -L "/etc/${rsource}" ] && continue        # Don't follow symlinks
        [ ! -f "/etc/${rsource}" ] && continue      # Does not exist

        n=$(echo ${rsource} | sed -e 's/[_-]release$//' -e 's/[_-]version$//')
        v=$( __parse_version_string "$( (grep VERSION /etc/${rsource}; cat /etc/${rsource}) | grep '[0-9]' | sed -e 'q' )" )
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
    DISTRO_VERSION=$(echo "${OS_VERSION}" | sed -e 's;[()];;' -e 's/-.*$//')
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
__gather_system_info


echo " * System Information:"
echo "     CPU:          ${CPU_VENDOR_ID}"
echo "     CPU Arch:     ${CPU_ARCH}"
echo "     OS Name:      ${OS_NAME}"
echo "     OS Version:   ${OS_VERSION}"
echo "     Distribution: ${DISTRO_NAME} ${DISTRO_VERSION}"
echo

[ $INSTALL_MINION -eq 1 ] && echo " * INFO: Installing minion"
[ $INSTALL_MASTER -eq 1 ] && echo " * INFO: Installing master"
[ $INSTALL_SYNDIC -eq 1 ] && echo " * INFO: Installing syndic"


# Simplify version naming on functions
if [ "x${DISTRO_VERSION}" = "x" ]; then
    DISTRO_VERSION_NO_DOTS=""
    PREFIXED_DISTRO_VERSION_NO_DOTS=""
else
    DISTRO_VERSION_NO_DOTS="$(echo $DISTRO_VERSION | tr -d '.')"
    PREFIXED_DISTRO_VERSION_NO_DOTS="_${DISTRO_VERSION_NO_DOTS}"
fi
# Simplify distro name naming on functions
DISTRO_NAME_L=$(echo $DISTRO_NAME | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9_ ]//g' | sed -e 's|[:space:]+|_|g')


# Only Ubuntu has daily packages, let's let users know about that
if [ "${DISTRO_NAME_L}" != "ubuntu" ] && [ $ITYPE = "daily" ]; then
    echo " * ERROR: Only Ubuntu has daily packages support"
    exit 1
fi


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __function_defined
#   DESCRIPTION:  Checks if a function is defined within this scripts scope
#    PARAMETERS:  function name
#       RETURNS:  0 or 1 as in defined or not defined
#-------------------------------------------------------------------------------
__function_defined() {
    FUNC_NAME=$1
    if [ "$(command -v $FUNC_NAME)x" != "x" ]; then
        echo " * INFO: Found function $FUNC_NAME"
        return 0
    fi
    echo " * INFO: $FUNC_NAME not found...."
    return 1
}


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


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __apt_get_noinput
#   DESCRIPTION:  (DRY) apt-get install with noinput options
#-------------------------------------------------------------------------------
__apt_get_noinput() {
    apt-get install -y -o DPkg::Options::=--force-confold $@; return $?
}


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
#   Optionally, define a salt configuration function, which will be called if
#   the -c|config-dir option is passed. One of:
#       1. config_<distro>_<distro_version>_<install_type>_salt
#       2. config_<distro>_<distro_version>_salt
#       3. config_<distro>_<install_type>_salt
#       4. config_<distro>_salt
#       5. config_salt [THIS ONE IS ALREADY DEFINED AS THE DEFAULT]
#
#   To install salt, which, of course, is required, one of:
#       1. install_<distro>_<distro_version>_<install_type>
#       2. install_<distro>_<install_type>
#
#   Also optionally, define a post install function, one of:
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
    if [ $DISTRO_VERSION_NO_DOTS -gt 1204 ]; then
        # Above Ubuntu 12.04 add-apt-repository is in a different package
        __apt_get_noinput software-properties-common
    else
        __apt_get_noinput python-software-properties
    fi
    if [ $DISTRO_VERSION_NO_DOTS -lt 1110 ]; then
        add-apt-repository ppa:saltstack/salt
    else
        add-apt-repository -y ppa:saltstack/salt
    fi
    apt-get update
}

install_ubuntu_1110_deps() {
    apt-get update
    __apt_get_noinput python-software-properties
    add-apt-repository -y 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
    add-apt-repository -y ppa:saltstack/salt
    apt-get update
}

install_ubuntu_git_deps() {
    install_ubuntu_deps
    __apt_get_noinput git-core python-yaml python-m2crypto python-crypto msgpack-python python-zmq python-jinja2

    __git_clone_and_checkout

    # Let's trigger config_salt()
    if [ "$TEMP_CONFIG_DIR" = "null" ]; then
        TEMP_CONFIG_DIR="${SALT_GIT_CHECKOUT_DIR}/conf/"
        CONFIG_SALT_FUNC="config_salt"
    fi
}

install_ubuntu_1110_post() {
    add-apt-repository -y --remove 'deb http://us.archive.ubuntu.com/ubuntu/ oneiric universe'
}

install_ubuntu_stable() {
    packages=""
    if [ $INSTALL_MINION -eq 1 ]; then
        packages="${packages} salt-minion"
    fi
    if [ $INSTALL_MASTER -eq 1 ]; then
        packages="${packages} salt-master"
    fi
    if [ $INSTALL_SYNDIC -eq 1 ]; then
        packages="${packages} salt-syndic"
    fi
    __apt_get_noinput ${packages}
}

install_ubuntu_daily() {
    install_ubuntu_stable
}

install_ubuntu_git() {
    python setup.py install --install-layout=deb
}

install_ubuntu_git_post() {
    for fname in minion master syndic; do

        # Skip if not meant to be installed
        [ $fname = "minion" ] && [ $INSTALL_MINION -eq 0 ] && continue
        [ $fname = "master" ] && [ $INSTALL_MASTER -eq 0 ] && continue
        [ $fname = "syndic" ] && [ $INSTALL_SYNDIC -eq 0 ] && continue

        if [ -f /sbin/initctl ]; then
            # We have upstart support
            /sbin/initctl status salt-$fname > /dev/null 2>&1
            if [ $? -eq 1 ]; then
                # upstart does not know about our service, let's copy the proper file
                cp ${SALT_GIT_CHECKOUT_DIR}/pkg/salt-$fname.upstart /etc/init/salt-$fname.conf
            fi

            /sbin/initctl status salt-$fname > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                # upstart knows about this service
                /sbin/initctl restart salt-$fname > /dev/null 2>&1
                # Restart service
                [ $? -eq 0 ] && continue
                # Service was not running, let's try starting it
                /sbin/initctl start salt-$fname > /dev/null 2>&1
                [ $? -eq 0 ] && continue
                # We failed to start the service, let's test the SysV code bellow
            fi
        fi

        # No upstart support in Ubuntu!?
        if [ -f ${SALT_GIT_CHECKOUT_DIR}/debian/salt-$fname.init ]; then
            cp ${SALT_GIT_CHECKOUT_DIR}/debian/salt-$fname.init /etc/init.d/salt-$fname
            chmod +x /etc/init.d/salt-$fname
        fi
        /etc/init.d/salt-$fname restart
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
install_debian_deps() {
    apt-get update
}

install_debian_60_deps() {
    echo "deb http://backports.debian.org/debian-backports squeeze-backports main" >> \
        /etc/apt/sources.list.d/backports.list

    # Add madduck's repo since squeeze packages have been deprecated
    for fname in salt-common salt-master salt-minion salt-syndic salt-doc; do
        echo "Package: $fname"
        echo "Pin: release a=squeeze-backports"
        echo "Pin-Priority: 600"
        echo
    done > /etc/apt/preferences.d/local-salt-backport.pref

    cat <<_eof > /etc/apt/sources.list.d/local-madduck-backports.list
deb http://debian.madduck.net/repo squeeze-backports main
deb-src http://debian.madduck.net/repo squeeze-backports main
_eof

    wget -q http://debian.madduck.net/repo/gpg/archive.key
    apt-key add archive.key
    apt-get update
}

install_debian_git_deps() {
    apt-get update
    __apt_get_noinput lsb-release python python-pkg-resources python-crypto \
        python-jinja2 python-m2crypto python-yaml msgpack-python git python-zmq

    __git_clone_and_checkout

    # Let's trigger config_salt()
    if [ "$TEMP_CONFIG_DIR" = "null" ]; then
        TEMP_CONFIG_DIR="${SALT_GIT_CHECKOUT_DIR}/conf/"
        CONFIG_SALT_FUNC="config_salt"
    fi
}

install_debian_60_git_deps() {
    install_debian_60_deps  # Add backports
    install_debian_git_deps # Grab the actual deps
}

install_debian_stable() {
    packages=""
    if [ $INSTALL_MINION -eq 1 ]; then
        packages="${packages} salt-minion"
    fi
    if [ $INSTALL_MASTER -eq 1 ]; then
        packages="${packages} salt-master"
    fi
    if [ $INSTALL_SYNDIC -eq 1 ]; then
        packages="${packages} salt-syndic"
    fi
    __apt_get_noinput ${packages}
}


install_debian_60() {
    install_debian_stable
}

install_debian_git() {
    python setup.py install --install-layout=deb
}

install_debian_60_git() {
    install_debian_git
}

install_debian_git_post() {
    for fname in minion master syndic; do

        # Skip if not meant to be installed
        [ $fname = "minion" ] && [ $INSTALL_MINION -eq 0 ] && continue
        [ $fname = "master" ] && [ $INSTALL_MASTER -eq 0 ] && continue
        [ $fname = "syndic" ] && [ $INSTALL_SYNDIC -eq 0 ] && continue

        if [ -f ${SALT_GIT_CHECKOUT_DIR}/debian/salt-$fname.init ]; then
            cp ${SALT_GIT_CHECKOUT_DIR}/debian/salt-$fname.init /etc/init.d/salt-$fname
        fi
        chmod +x /etc/init.d/salt-$fname
        /etc/init.d/salt-$fname start
    done
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
    packages=""
    if [ $INSTALL_MINION -eq 1 ]; then
        packages="${packages} salt-minion"
    fi
    if [ $INSTALL_MASTER -eq 1 ] || [ $INSTALL_SYNDIC -eq 1 ]; then
        packages="${packages} salt-master"
    fi
    yum install -y ${packages}
}

install_fedora_git_deps() {
    install_fedora_deps
    yum install -y git

    __git_clone_and_checkout

    # Let's trigger config_salt()
    if [ "$TEMP_CONFIG_DIR" = "null" ]; then
        TEMP_CONFIG_DIR="${SALT_GIT_CHECKOUT_DIR}/conf/"
        CONFIG_SALT_FUNC="config_salt"
    fi
}

install_fedora_git() {
    python setup.py install
}

install_fedora_git_post() {
    for fname in minion master syndic; do

        # Skip if not meant to be installed
        [ $fname = "minion" ] && [ $INSTALL_MINION -eq 0 ] && continue
        [ $fname = "master" ] && [ $INSTALL_MASTER -eq 0 ] && continue
        [ $fname = "syndic" ] && [ $INSTALL_SYNDIC -eq 0 ] && continue

        cp ${SALT_GIT_CHECKOUT_DIR}/pkg/rpm/salt-$fname.service /lib/systemd/system/salt-$fname.service

        systemctl is-enabled salt-$fname.service || (systemctl preset salt-$fname.service && systemctl enable salt-$fname.service)
        sleep 0.1
        systemctl daemon-reload
        sleep 0.1
        systemctl try-restart salt-$fname.service
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
        EPEL_ARCH="i386"
    else
        EPEL_ARCH=$CPU_ARCH_L
    fi
    rpm -Uvh --force http://mirrors.kernel.org/fedora-epel/6/${EPEL_ARCH}/epel-release-6-8.noarch.rpm
    yum -y update
}

install_centos_63_stable() {
    packages=""
    if [ $INSTALL_MINION -eq 1 ]; then
        packages="${packages} salt-minion"
    fi
    if [ $INSTALL_MASTER -eq 1 ] || [ $INSTALL_SYNDIC -eq 1 ]; then
        packages="${packages} salt-master"
    fi
    yum -y install ${packages} --enablerepo=epel-testing
}

install_centos_63_stable_post() {
    for fname in minion master syndic; do
        # Skip if not meant to be installed
        [ $fname = "minion" ] && [ $INSTALL_MINION -eq 0 ] && continue
        [ $fname = "master" ] && [ $INSTALL_MASTER -eq 0 ] && continue
        [ $fname = "syndic" ] && [ $INSTALL_SYNDIC -eq 0 ] && continue

        if [ -f /sbin/initctl ]; then
            # We have upstart support
            /sbin/initctl status salt-$fname > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                # upstart knows about this service
                /sbin/initctl restart salt-$fname > /dev/null 2>&1
                # Restart service
                [ $? -eq 0 ] && continue
                # Service was not running, let's try starting it
                /sbin/initctl start salt-$fname > /dev/null 2>&1
                [ $? -eq 0 ] && continue
                # We failed to start the service, let's test the SysV code bellow
            fi
        fi

        if [ -f /etc/init.d/salt-$fname ]; then
            # Still in SysV init!?
            /sbin/chkconfig salt-$fname on
            /etc/init.d/salt-$fname start
        fi
    done
}

install_centos_62_stable_deps() {
    install_centos_63_stable_deps
}

install_centos_62_stable() {
    install_centos_63_stable
}

install_centos_62_stable_post() {
    install_centos_63_stable_post
}

install_centos_63_git_deps() {
    install_centos_63_stable_deps
    yum -y install git PyYAML m2crypto python-crypto python-msgpack python-zmq python-jinja2 --enablerepo=epel-testing

    __git_clone_and_checkout

    # Let's trigger config_salt()
    if [ "$TEMP_CONFIG_DIR" = "null" ]; then
        TEMP_CONFIG_DIR="${SALT_GIT_CHECKOUT_DIR}/conf/"
        CONFIG_SALT_FUNC="config_salt"
    fi

}

install_centos_63_git() {
    rm -rf /usr/lib/python*/site-packages/salt
    rm -rf /usr/bin/salt*

    python2 setup.py install
}

install_centos_63_git_post() {
    for fname in master minion syndic; do

        # Skip if not meant to be installed
        [ $fname = "minion" ] && [ $INSTALL_MINION -eq 0 ] && continue
        [ $fname = "master" ] && [ $INSTALL_MASTER -eq 0 ] && continue
        [ $fname = "syndic" ] && [ $INSTALL_SYNDIC -eq 0 ] && continue

        if [ -f /sbin/initctl ]; then
            # We have upstart support
            /sbin/initctl status salt-$fname > /dev/null 2>&1
            if [ $? -eq 1 ]; then
                # upstart does not know about our service, let's copy the proper file
                cp ${SALT_GIT_CHECKOUT_DIR}/pkg/salt-$fname.upstart /etc/init/salt-$fname.conf
            fi

            /sbin/initctl status salt-$fname > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                # upstart knows about this service
                /sbin/initctl restart salt-$fname > /dev/null 2>&1
                # Restart service
                [ $? -eq 0 ] && continue
                # Service was not running, let's try starting it
                /sbin/initctl start salt-$fname > /dev/null 2>&1
                [ $? -eq 0 ] && continue
                # We failed to start the service, let's test the SysV code bellow
            fi
        fi


        # Still in SysV init?!
        if [ ! -f /etc/init.d/salt-$fname ]; then
            cp ${SALT_GIT_CHECKOUT_DIR}/pkg/rpm/salt-${fname} /etc/init.d/
            chmod +x /etc/init.d/salt-${fname}
        fi
        /sbin/chkconfig salt-${fname} on
        /etc/init.d/salt-${fname} start
    done
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
    grep '\[salt\]' /etc/pacman.conf >/dev/null 2>&1 || echo '[salt]
Server = http://intothesaltmine.org/archlinux
' >> /etc/pacman.conf
}

install_arch_git_deps() {
    grep '\[salt\]' /etc/pacman.conf >/dev/null 2>&1 || echo '[salt]
Server = http://intothesaltmine.org/archlinux
' >> /etc/pacman.conf

    pacman -Sy --noconfirm pacman git python2-crypto python2-distribute \
        python2-jinja  python2-m2crypto python2-markupsafe python2-msgpack \
        python2-psutil python2-pyzmq zeromq

    __git_clone_and_checkout

    # Let's trigger config_salt()
    if [ "$TEMP_CONFIG_DIR" = "null" ]; then
        TEMP_CONFIG_DIR="${SALT_GIT_CHECKOUT_DIR}/conf/"
        CONFIG_SALT_FUNC="config_salt"
    fi
}

install_arch_stable() {
    pacman -Sy --noconfirm pacman
    pacman -Syu --noconfirm salt
}

install_arch_git() {
    python2 setup.py install
}

install_arch_post() {
    for fname in minion master syndic; do

        # Skip if not meant to be installed
        [ $fname = "minion" ] && [ $INSTALL_MINION -eq 0 ] && continue
        [ $fname = "master" ] && [ $INSTALL_MASTER -eq 0 ] && continue
        [ $fname = "syndic" ] && [ $INSTALL_SYNDIC -eq 0 ] && continue

        if [ -f /usr/bin/systemctl ]; then
            # Using systemd
            /usr/bin/systemctl is-enabled salt-$fname.service > /dev/null 2>&1 || (
                /usr/bin/systemctl preset salt-$fname.service > /dev/null 2>&1 &&
                /usr/bin/systemctl enable salt-$fname.service > /dev/null 2>&1
            )
            sleep 0.1
            /usr/bin/systemctl daemon-reload
            sleep 0.1
            /usr/bin/systemctl try-restart salt-$fname.service
            continue
        fi
        /etc/rc.d/salt-$fname start
    done
}

install_arch_git_post() {
    for fname in minion master syndic; do

        # Skip if not meant to be installed
        [ $fname = "minion" ] && [ $INSTALL_MINION -eq 0 ] && continue
        [ $fname = "master" ] && [ $INSTALL_MASTER -eq 0 ] && continue
        [ $fname = "syndic" ] && [ $INSTALL_SYNDIC -eq 0 ] && continue

        if [ -f /usr/bin/systemctl ]; then
            cp ${SALT_GIT_CHECKOUT_DIR}/pkg/rpm/salt-$fname.service /lib/systemd/system/salt-$fname.service

            /usr/bin/systemctl is-enabled salt-$fname.service > /dev/null 2>&1 || (
                /usr/bin/systemctl preset salt-$fname.service > /dev/null 2>&1 &&
                /usr/bin/systemctl enable salt-$fname.service > /dev/null 2>&1
            )
            sleep 0.1
            /usr/bin/systemctl daemon-reload
            sleep 0.1
            /usr/bin/systemctl try-restart salt-$fname.service
            continue
        fi

        # SysV init!?
        cp ${SALT_GIT_CHECKOUT_DIR}/pkg/rpm/salt-$fname /etc/rc.d/init.d/salt-$fname
        chmod +x /etc/rc.d/init.d/salt-$fname
        /etc/init.d/salt-$fname start
    done
}
#
#   Ended Arch Install Functions
#
##############################################################################

##############################################################################
#
#   FreeBSD Install Functions
#
install_freebsd_90_stable_deps() {
    if [ $CPU_ARCH_L = "amd64" ]; then
        BSD_ARCH="x86:64"
    elif [ $CPU_ARCH_L = "x86_64" ]; then
        BSD_ARCH="x86:64"
    elif [ $CPU_ARCH_L = "i386" ]; then
        BSD_ARCH="x86:32"
    elif [ $CPU_ARCH_L = "i686" ]; then
        BSD_ARCH="x86:32"
    fi

    fetch http://pkgbeta.freebsd.org/freebsd:9:${BSD_ARCH}/latest/Latest/pkg.txz
    tar xf ./pkg.txz -s ",/.*/,,g" "*/pkg-static"
    ./pkg-static add ./pkg.txz
    /usr/local/sbin/pkg2ng
    echo "PACKAGESITE: http://pkgbeta.freebsd.org/freebsd:9:${BSD_ARCH}/latest" > /usr/local/etc/pkg.conf

    /usr/local/sbin/pkg install -y swig
}

install_freebsd_git_deps() {
    if [ $CPU_ARCH_L = "amd64" ]; then
        BSD_ARCH="x86:64"
    elif [ $CPU_ARCH_L = "x86_64" ]; then
        BSD_ARCH="x86:64"
    elif [ $CPU_ARCH_L = "i386" ]; then
        BSD_ARCH="x86:32"
    elif [ $CPU_ARCH_L = "i686" ]; then
        BSD_ARCH="x86:32"
    fi

    fetch http://pkgbeta.freebsd.org/freebsd:9:${BSD_ARCH}/latest/Latest/pkg.txz
    tar xf ./pkg.txz -s ",/.*/,,g" "*/pkg-static"
    ./pkg-static add ./pkg.txz
    /usr/local/sbin/pkg2ng
    echo "PACKAGESITE: http://pkgbeta.freebsd.org/freebsd:9:${BSD_ARCH}/latest" > /usr/local/etc/pkg.conf

    /usr/local/sbin/pkg install -y swig

    __git_clone_and_checkout
    # Let's trigger config_salt()
    if [ "$TEMP_CONFIG_DIR" = "null" ]; then
        TEMP_CONFIG_DIR="${SALT_GIT_CHECKOUT_DIR}/conf/"
        CONFIG_SALT_FUNC="config_salt"
    fi
}

install_freebsd_90_stable() {
    /usr/local/sbin/pkg install -y salt
}

install_freebsd_git() {
    /usr/local/sbin/pkg install -y git salt
    /usr/local/sbin/pkg delete -y salt

    /usr/local/bin/python setup.py install
}

install_freebsd_90_stable_post() {
    salt-minion -d
}

install_freebsd_git_post() {
    salt-minion -d
}
#
#   Ended FreeBSD Install Functions
#
##############################################################################


##############################################################################
#
#   Default minion configuration function. Matches ANY distribution as long as
#   the -c options is passed.
#
config_salt() {
    # If the configuration directory is not passed, return
    [ "$TEMP_CONFIG_DIR" = "null" ] && return
    # If the configuration directory does not exist, error out
    if [ ! -d "$TEMP_CONFIG_DIR" ]; then
        echo " * The configuration directory ${TEMP_CONFIG_DIR} does not exist."
        exit 1
    fi

    SALT_DIR=/etc/salt
    PKI_DIR=$SALT_DIR/pki
    # Let's create the necessary directories
    [ -d $SALT_DIR ] || mkdir $SALT_DIR
    [ -d $PKI_DIR ] || mkdir -p $PKI_DIR && chmod 700 $PKI_DIR

    if [ $INSTALL_MINION -eq 1 ]; then
        # Create the PKI directory
        [ -d $PKI_DIR/minion ] || mkdir -p $PKI_DIR/minion && chmod 700 $PKI_DIR/minion

        # Copy the minions configuration if found
        [ -f "$TEMP_CONFIG_DIR/minion" ] && mv "$TEMP_CONFIG_DIR/minion" /etc/salt

        # Copy the minion's keys if found
        if [ -f "$TEMP_CONFIG_DIR/minion.pem" ]; then
            mv "$TEMP_CONFIG_DIR/minion.pem" $PKI_DIR/minion/
            chmod 400 $PKI_DIR/minion/minion.pem
        fi
        if [ -f "$TEMP_CONFIG_DIR/minion.pub" ]; then
            mv "$TEMP_CONFIG_DIR/minion.pub" $PKI_DIR/minion/
            chmod 664 $PKI_DIR/minion/minion.pub
        fi
    fi


    if [ $INSTALL_MASTER -eq 1 ] || [ $INSTALL_SYNDIC -eq 1 ]; then
        # Create the PKI directory
        [ -d $PKI_DIR/master ] || mkdir -p $PKI_DIR/master && chmod 700 $PKI_DIR/master

        # Copy the masters configuration if found
        [ -f "$TEMP_CONFIG_DIR/master" ] && mv "$TEMP_CONFIG_DIR/master" /etc/salt

        # Copy the master's keys if found
        if [ -f "$TEMP_CONFIG_DIR/master.pem" ]; then
            mv "$TEMP_CONFIG_DIR/master.pem" $PKI_DIR/master/
            chmod 400 $PKI_DIR/master/master.pem
        fi
        if [ -f "$TEMP_CONFIG_DIR/master.pub" ]; then
            mv "$TEMP_CONFIG_DIR/master.pub" $PKI_DIR/master/
            chmod 664 $PKI_DIR/master/master.pub
        fi
    fi
}
#
#  Ended Default Configuration function
#
##############################################################################


#=============================================================================
# LET'S PROCEED WITH OUR INSTALLATION
#=============================================================================
# Let's get the dependencies install function
DEP_FUNC_NAMES="install_${DISTRO_NAME_L}${PREFIXED_DISTRO_VERSION_NO_DOTS}_${ITYPE}_deps"
DEP_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}${PREFIXED_DISTRO_VERSION_NO_DOTS}_deps"
DEP_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}_${ITYPE}_deps"
DEP_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}_deps"

DEPS_INSTALL_FUNC="null"
for DEP_FUNC_NAME in $DEP_FUNC_NAMES; do
    if __function_defined $DEP_FUNC_NAME; then
        DEPS_INSTALL_FUNC=$DEP_FUNC_NAME
        break
    fi
done


# Let's get the minion config function
CONFIG_SALT_FUNC="null"
if [ "$TEMP_CONFIG_DIR" != "null" ]; then
    CONFIG_FUNC_NAMES="config_${DISTRO_NAME_L}${PREFIXED_DISTRO_VERSION_NO_DOTS}_${ITYPE}_salt"
    CONFIG_FUNC_NAMES="$CONFIG_FUNC_NAMES config_${DISTRO_NAME_L}${PREFIXED_DISTRO_VERSION_NO_DOTS}_salt"
    CONFIG_FUNC_NAMES="$CONFIG_FUNC_NAMES config_${DISTRO_NAME_L}_${ITYPE}_salt"
    CONFIG_FUNC_NAMES="$CONFIG_FUNC_NAMES config_${DISTRO_NAME_L}_salt"
    CONFIG_FUNC_NAMES="$CONFIG_FUNC_NAMES config_salt"

    for FUNC_NAME in $CONFIG_FUNC_NAMES; do
        if __function_defined $FUNC_NAME; then
            CONFIG_SALT_FUNC=$FUNC_NAME
            break
        fi
    done
fi


# Let's get the install function
INSTALL_FUNC_NAMES="install_${DISTRO_NAME_L}${PREFIXED_DISTRO_VERSION_NO_DOTS}_${ITYPE}"
INSTALL_FUNC_NAMES="$INSTALL_FUNC_NAMES install_${DISTRO_NAME_L}_${ITYPE}"

INSTALL_FUNC="null"
for FUNC_NAME in $INSTALL_FUNC_NAMES; do
    if __function_defined $FUNC_NAME; then
        INSTALL_FUNC=$FUNC_NAME
        break
    fi
done


# Let's get the post install function
POST_FUNC_NAMES="install_${DISTRO_NAME_L}${PREFIXED_DISTRO_VERSION_NO_DOTS}_${ITYPE}_post"
POST_FUNC_NAMES="$POST_FUNC_NAMES install_${DISTRO_NAME_L}${PREFIXED_DISTRO_VERSION_NO_DOTS}_post"
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

if [ $INSTALL_FUNC = "null" ]; then
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


# Configure Salt
if [ "$TEMP_CONFIG_DIR" != "null" ] && [ "$CONFIG_SALT_FUNC" != "null" ]; then
    echo " * Running ${CONFIG_SALT_FUNC}()"
    $CONFIG_SALT_FUNC
    if [ $? -ne 0 ]; then
        echo " * Failed to run ${CONFIG_SALT_FUNC}()!!!"
        exit 1
    fi
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
