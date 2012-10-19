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

# Remove the logging pipe when the script exits
trap "rm -f $LOGPIPE" EXIT

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
#          NAME:  __gather_os_info
#   DESCRIPTION:  Discover operating system information
#-------------------------------------------------------------------------------
__gather_os_info() {
    OS_NAME=$(uname -s 2>/dev/null)
    OS_NAME_L=$( echo $OS_NAME | tr '[:upper:]' '[:lower:]' )
    OS_VERSION=$(uname -r)
    OS_VERSION_L=$( echo $OS_VERSION | tr '[:upper:]' '[:lower:]' )
    MACHINE=$(uname -m 2>/dev/null || uname -p 2>/dev/null || echo "unknown")
}
__gather_os_info


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  __gather_linux_system_info
#   DESCRIPTION:  Discover Linux system information
#-------------------------------------------------------------------------------
__gather_linux_system_info() {
    DISTRO_NAME=""
    DISTRO_VERSION=""

    if [ -f /etc/lsb-release ]; then
        DISTRO_NAME=$(grep DISTRIB_ID /etc/lsb-release | sed -e 's/.*=//')
        DISTRO_VERSION=$(grep DISTRIB_RELEASE /etc/lsb-release | sed -e 's/.*=//')
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
        v=$(
            (grep VERSION /etc/${rsource}; cat /etc/${rsource}) | grep '[0-9]' | sed -e 'q' |\
            sed -e 's/^/#/' \
                -e 's/^#[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\)\(\.[0-9][0-9]*\).*$/\1[\2]/' \
                -e 's/^#[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\).*$/\1/' \
                -e 's/^#[^0-9]*\([0-9][0-9]*\).*$/\1/' \
                -e 's/^#.*$//'
        )
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

echo " * System Information:"
echo "     OS Name:      ${OS_NAME}"
echo "     OS Version:   ${OS_VERSION}"
echo "     Machine:      ${MACHINE}"
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
#       4. install_<distro>_dep
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
##############################################################################
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
#
#   Ended Debian Install Functions
#
##############################################################################

##############################################################################
#
#   CentOS Install Functions
#
install_centos_63_stable_deps() {
    rpm -Uvh --force http://mirrors.kernel.org/fedora-epel/6/x86_64/epel-release-6-7.noarch.rpm
    yum -y update
}

install_centos_63_stable() {
    yum -y install salt-minion --enablerepo=epel-testing
}

install_centos_63_stable_post() {
    /sbin/chkconfig salt-minion on
    salt-minion start &
}
#
#   Ended CentOS Install Functions
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
POST_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}${DISTRO_VERSION_NO_DOTS}_post"
POST_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}_${ITYPE}_post"
POST_FUNC_NAMES="$DEP_FUNC_NAMES install_${DISTRO_NAME_L}_post"

POST_INSTALL_FUNC="null"
for FUNC_NAME in $POST_FUNC_NAMES; do
    if __function_defined $FUNC_NAME; then
        DEPS_INSTALL_FUNC=$FUNC_NAME
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

# Install Salt
echo " * Running ${INSTALL_FUNC}()"
$INSTALL_FUNC

# Run any post install function
if [ "$POST_INSTALL_FUNC" != "null" ]; then
    echo " * Running ${POST_INSTALL_FUNC}()"
    $POST_INSTALL_FUNC
fi

# Done!
echo " * Salt installed!"
