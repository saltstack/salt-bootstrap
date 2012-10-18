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
#===  FUNCTION  ================================================================
#         NAME:  usage
#  DESCRIPTION:  Display usage information.
#===============================================================================
usage() {
    cat << EOT

  Usage :  ${0##/*/} [options] <install-type>

  Installation types:
    - stable (default)
    - daily
    - git

  Options:
  -h|help       Display this message
  -v|version    Display script version
EOT
}   # ----------  end of function usage  ----------

#-----------------------------------------------------------------------
#  Handle command line arguments
#-----------------------------------------------------------------------

while getopts ":hvN" opt
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
fi

if [ "$ITYPE" != "stable" -a "$ITYPE" != "daily" -a "$ITYPE" != "git" ]; then
    echo " ERROR: Installation type \"$ITYPE\" is not known..."
    exit 1
fi

# Root permissions are required to run this script
if [ $(whoami) != "root" ] ; then
    echo " * ERROR: Salt requires root privileges to install. Please re-run this script as root."
    exit 1
fi

# Create a temporary directory used for any temp files created
TMPDIR="/tmp/salty-temp"
if [ ! -d $TMPDIR ]; then
    echo " * Creating temporary directory ${TMPDIR} "
    mkdir $TMPDIR
fi
# Store current directory
STORED_PWD=$(pwd)
# Change to temp directory
cd $TMPDIR
# When the script exits, change to the initial directory.
trap "cd $STORED_PWD" EXIT

# Define our logging file and pipe
LOGFILE="/tmp/$(basename $0).log"
LOGPIPE="/tmp/$(basename $0).logpipe"

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

# Define some SHTOOL variables
SHTOOL_COMMON="sh.common"
SHTOOL_COMMON_MD5='2fdd8ccf7122df039cdf79a9f7a083e4'
SHTOOL_COMMON_LINK='http://cvs.ossp.org/getfile?f=ossp-pkg/shtool/sh.common&v=1.24'
SHTOOL_PLATFORM="shtool.platform"
SHTOOL_PLATFORM_MD5='bf4c782746e1c92923fb66de513f9295'
SHTOOL_PLATFORM_LINK='http://cvs.ossp.org/getfile?f=ossp-pkg/shtool/sh.platform&v=1.31'


#===  FUNCTION  ================================================================
#         NAME:  shtool
#  DESCRIPTION:  Run shtool commands.
#===============================================================================
shtool() {
    OPWD=$(pwd)
    cd $TMPDIR
    echo $(sh ./shtool.platform "$@")
    cd $OPWD
}


#===  FUNCTION  ================================================================
#         NAME:  download_shtool
#  DESCRIPTION:  Download shtool required scripts
#===============================================================================
download_shtool() {
    if [ ! -f $SHTOOL_COMMON ]; then
        echo "Download SHTOOL sh.common from $SHTOOL_COMMON_LINK"
        wget $SHTOOL_COMMON_LINK -O $SHTOOL_COMMON
        MD5SUM=$(md5sum $SHTOOL_COMMON | awk '{ print $1 }')
        if [ "$MD5SUM" != "$SHTOOL_COMMON_MD5" ]; then
            echo "MD5 signature of sh.common does not match!"
            exit 1
        fi
    fi

    if [ ! -f $SHTOOL_PLATFORM ]; then
        echo "Download sh.platform from $SHTOOL_PLATFORM_LINK"
        wget $SHTOOL_PLATFORM_LINK -O $SHTOOL_PLATFORM
        MD5SUM=$(md5sum $SHTOOL_PLATFORM | awk '{ print $1 }')
        if [ "$MD5SUM" != "$SHTOOL_PLATFORM_MD5" ]; then
            echo "MD5 signature of shtool.platform does not match!"
            exit 1
        fi
    fi
}

echo " * Downloading shtool required scripts for system detection"
download_shtool
echo " * Downloaded required shtool scripts"

echo " * Detecting system:"

ARCH=$(shtool -F "%at")

FULL_SYSTEM=$(shtool -F '%<st>' -L -S '|' -C '+')
SYSTEM_NAME=$(echo $FULL_SYSTEM | cut -d \| -f1 )
SYSTEM_VERSION=$(echo $FULL_SYSTEM | cut -d \| -f2 )

FULL_DISTRO=$(shtool -F '%<sp>' -L -S '|' -C '+')
DISTRO_NAME=$(echo $FULL_DISTRO | cut -d \| -f1 )
DISTRO_VERSION=$(echo $FULL_DISTRO | cut -d \| -f2 )

echo "    System Information:"
echo "      System:\t\t${FULL_SYSTEM}"
echo "      Architecture:\t${ARCH}"
echo "      Distribution:\t${DISTRO_NAME} ${DISTRO_VERSION}"

if [ $SYSTEM_NAME != "linux" ]; then
    echo " * ERROR: Only Linux is currently supported"
    exit 1
fi

# Black Magic Below!!!
INSTALL_FUNC=""

###############################################################################################
#
#   Distribution install functions
#
#   In order to install salt for a distribution you need to define:
#
#   To Install Dependencies, which is required, one of:
#       1. install_<distro>_<distro_version>_<install_type>_deps
#       2. install_<distro>_<distro_version>_deps
#       3. install_<distro>_deps
#
#
#   To install salt, which, of course, is required, one of:
#       1. install_<distro>_<distro_version>_<install_type>
#       1. install_<distro>_<install_type>
#
#   And optionally, define a post install function, one of:
#       1. install_<distro>_<distro_versions>_<install_type>_post
#       2. install_<distro>_<distro_versions>_post
#       3. install_<distro>_post
#
###############################################################################################

###############################################################################################
#
#   Ubuntu Install Functions
#
###############################################################################################
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
###############################################################################################

###############################################################################################
#
#   Debian Install Functions
#
install_debian_60_stable_deps() {
    echo "deb http://backports.debian.org/debian-backports squeeze-backports main" >> /etc/apt/sources.list.d/backports.list
    apt-get update
}

install_debian_60_stable() {
    apt-get -t squeeze-backports -y install salt-minion
}
#
#   Ended Debian Install Functions
#
###############################################################################################

###############################################################################################
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
###############################################################################################


###############################################################################################
###############################################################################################
###############################################################################################
###
###   NO NEED TO CHANGE ANYTHING BELLOW
###
###############################################################################################
###############################################################################################
###############################################################################################

# Let's get the dependencies install function
DEPS_INSTALL_FUNC="install_${DISTRO_NAME}_$(echo $DISTRO_VERSION | tr -d '.')_${ITYPE}_deps"
if [ "$(! type ${DEPS_INSTALL_FUNC} | grep -q 'shell function')" != "" ]; then
    echo " * INFO: ${DEPS_INSTALL_FUNC} not found..."
    # let's try and see if have a deps function which ignores the installation type
    DEPS_INSTALL_FUNC="install_${DISTRO_NAME}_$(echo $DISTRO_VERSION | tr -d '.')_deps"
    if [ "$( ! type ${DEPS_INSTALL_FUNC} | grep -q 'shell function' )" != "" ]; then
        echo " * INFO: ${DEPS_INSTALL_FUNC} not found..."
        # Let's try to see if we have a deps function which also ignores the distro version
        DEPS_INSTALL_FUNC="install_${DISTRO_NAME}_deps"
        if [ "$( ! type ${DEPS_INSTALL_FUNC} | grep -q 'shell function' )" != "" ]; then
            echo " * ERROR: Installation not supported not supported. Can't find ${DEPS_INSTALL_FUNC}()"
            exit 1
        fi
    fi
fi

# Let's get the install function
INSTALL_FUNC="install_${DISTRO_NAME}_$(echo $DISTRO_VERSION | tr -d '.')_${ITYPE}"
if [ "$( ! type ${INSTALL_FUNC} | grep -q 'shell function' )" != "" ]; then
    echo " * INFO: ${INSTALL_FUNC} not found..."
    # Let see if we have an install function which ignores the distribution version
    INSTALL_FUNC="install_${DISTRO_NAME}_${ITYPE}"
    if [ "$( ! type ${INSTALL_FUNC} | grep -q 'shell function' )" != "" ]; then
        echo " * ERROR: Installation not supported not supported. Can't find ${INSTALL_FUNC}()"
        exit 1
    fi
fi

# Let's get the post function, if any, it's optional
POST_INSTALL_FUNC="install_${DISTRO_NAME}_$(echo $DISTRO_VERSION | tr -d '.')_${ITYPE}_post"
if [ "$( ! type ${POST_INSTALL_FUNC} | grep -q 'shell function' )" != "" ]; then
    echo " * INFO: ${POST_INSTALL_FUNC} not found..."
    # let's try and see if have a post function which ignores the installation type
    POST_INSTALL_FUNC="install_${DISTRO_NAME}_$(echo $DISTRO_VERSION | tr -d '.')_post"
    if [ "$( ! type ${POST_INSTALL_FUNC} | grep -q 'shell function' )" != "" ]; then
        echo " * INFO: ${POST_INSTALL_FUNC} not found..."
        # Let's try to see if we have a deps function which also ignores the distro version
        POST_INSTALL_FUNC="install_${DISTRO_NAME}_post"
        if [ "$( ! type ${POST_INSTALL_FUNC} | grep -q 'shell function' )" != "" ]; then
            echo " * INFO: ${POST_INSTALL_FUNC} not found..."
            POST_INSTALL_FUNC=""
        fi
    fi
fi

# Install dependencies
echo " * Running ${DEPS_INSTALL_FUNC}()"
$DEPS_INSTALL_FUNC

# Install Salt
echo " * Running ${INSTALL_FUNC}()"
$INSTALL_FUNC

# Run any post install function
if [ "$POST_INSTALL_FUNC" != "" ]; then
    echo " * Running ${POST_INSTALL_FUNC}()"
    $POST_INSTALL_FUNC
fi

# Done!
echo " * Salt installed!"
