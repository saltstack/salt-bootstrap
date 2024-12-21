#!/bin/sh

__ScriptName="salt-quick-start.sh"
SALT_REPO_URL="https://packages.broadcom.com/artifactory/salt-project-generic/onedir"
_COLORS=${QS_COLORS:-$(tput colors 2>/dev/null || echo 0)}

_LOCAL=0
_FULL=0
_STOP=0

PWD="$(pwd)"
_PATH=${PWD}/salt


__usage() {
    cat << EOT

  Usage :  ${__ScriptName} [options]

  Options:
    -h  Show usage.
    -f  Full setup with a Salt minion and Salt master running.
    -l  Local setup, no Salt minion or Salt master running.
    -s  Attempt to stop a running Salt minion and Salt master.

EOT
}   # ----------  end of function __usage  ----------


echoinfo() {
    printf "${GC} *  INFO${EC}: %s\\n" "$@";
}

echoerror() {
    printf "${RC} * ERROR${EC}: %s\\n" "$@" 1>&2;
}

__detect_color_support() {
    # shellcheck disable=SC2181
    if [ $? -eq 0 ] && [ "$_COLORS" -gt 2 ]; then
        RC='\033[1;31m'
        GC='\033[1;32m'
        BC='\033[1;34m'
        YC='\033[1;33m'
        EC='\033[0m'
    else
        RC=""
        GC=""
        BC=""
        YC=""
        EC=""
    fi
}

__detect_color_support

while getopts ':fhls' opt
do
  case "${opt}" in

    h )  __usage; exit 0  ;;
    l )  _LOCAL=1         ;;
    f )  _FULL=1          ;;
    s )  _STOP=1          ;;

  esac    # --- end of case ---
done
shift $((OPTIND-1))

if [[ "${_STOP}" == "1" ]]; then
  if [[ -f "${_PATH}/var/run/salt-minion.pid" ]]; then
    echoinfo "Stopping the salt-minion"
    kill $(cat "${_PATH}/var/run/salt-minion.pid")
  else
    echoerror "${_PATH}/var/run/salt-minion.pid not found"
  fi
  if [[ -f "${_PATH}/var/run/salt-master.pid" ]]; then
    echoinfo "Stopping the salt-master"
    kill $(cat "${_PATH}/var/run/salt-master.pid")
  else
    echoerror "${_PATH}/var/run/salt-master.pid not found"
  fi
  exit 0
fi

if [[ "$_LOCAL" == "1" && "$_FULL" == "1" ]]; then
  echo "Only specify either local or full"
  exit 0
fi

__parse_repo_json_jq() {

    # $1 is OS_NAME
    # $2 is ARCH

    # get dir listing from url, sort and pick highest
    onedir_versions_tmpf=$(mktemp)
    curr_pwd=$(pwd)
    cd  ${onedir_versions_tmpf} || return 1
    wget -r -np -nH --exclude-directories=onedir,relenv,windows -x -l 1 "$SALT_REPO_URL/"
    # shellcheck disable=SC2010
    LATEST_VERSION=$(ls artifactory/saltproject-generic/onedir/ | grep -v 'index.html' | sort -V -u | tail -n 1)
    cd ${curr_pwd} || return "${LATEST_VERSION}"
    rm -fR ${onedir_versions_tmpf}
    _JSON_VERSION="${LATEST_VERSION}"
}

__fetch_url() {
    # shellcheck disable=SC2086
    curl $_CURL_ARGS -L -s -f -o "$1" "$2" >/dev/null 2>&1     ||
        wget $_WGET_ARGS -q -O "$1" "$2" >/dev/null 2>&1       ||
            fetch $_FETCH_ARGS -q -o "$1" "$2" >/dev/null 2>&1 ||  # FreeBSD
                fetch -q -o "$1" "$2" >/dev/null 2>&1          ||  # Pre FreeBSD 10
                    ftp -o "$1" "$2" >/dev/null 2>&1           ||  # OpenBSD
                        (echoerror "$2 failed to download to $1"; exit 1)
}

__gather_os_info() {
    OS_NAME=$(uname -s 2>/dev/null)
    OS_NAME_L=$( echo "$OS_NAME" | tr '[:upper:]' '[:lower:]' )
    OS_VERSION=$(uname -r)
    # shellcheck disable=SC2034
    OS_VERSION_L=$( echo "$OS_VERSION" | tr '[:upper:]' '[:lower:]' )
}

__gather_hardware_info() {
    if [ -f /proc/cpuinfo ]; then
        CPU_VENDOR_ID=$(awk '/vendor_id|Processor/ {sub(/-.*$/,"",$3); print $3; exit}' /proc/cpuinfo )
    elif [ -f /usr/bin/kstat ]; then
        # SmartOS.
        # Solaris!?
        # This has only been tested for a GenuineIntel CPU
        CPU_VENDOR_ID=$(/usr/bin/kstat -p cpu_info:0:cpu_info0:vendor_id | awk '{print $2}')
    else
        CPU_VENDOR_ID=$( sysctl -n hw.model )
    fi
    # shellcheck disable=SC2034
    CPU_VENDOR_ID_L=$( echo "$CPU_VENDOR_ID" | tr '[:upper:]' '[:lower:]' )
    CPU_ARCH=$(uname -m 2>/dev/null || uname -p 2>/dev/null || echo "unknown")
    CPU_ARCH_L=$( echo "$CPU_ARCH" | tr '[:upper:]' '[:lower:]' )
}

__gather_hardware_info
__gather_os_info

_DARWIN_ARM=0
if [[ "${OS_NAME_L}" == "darwin" ]]; then
  OS_NAME="macos"
  # Use x86_64 packages until we are able build arm packages
  if [[ "${CPU_ARCH_L}" == "arm64" ]]; then
    CPU_ARCH_L="x86_64"
    _DARWIN_ARM=1
  fi
else
  OS_NAME="${OS_NAME_L}"
fi

__parse_repo_json_jq ${OS_NAME} ${CPU_ARCH_L}

FILE="salt-${_JSON_VERSION}-onedir-${OS_NAME_L}-${CPU_ARCH_L}.tar.xz"
URL="${SALT_REPO_URL}/${_JSON_VERSION}/${FILE}"

if [[ ! -f ${FILE} ]]; then
  echoinfo "Downloading Salt"
  __fetch_url "${FILE}" "${URL}"
fi

if [[ ! -d "salt" ]]; then
  echoinfo "Extracting Salt"
  tar xf ${FILE}

  # very very hacky, remove ASAP
  if [[ "${_DARWIN_ARM}" == "1" ]]; then
    mkdir -p ${_PATH}/opt/openssl/lib
    ln -s ${_PATH}/lib/libcrypto.dylib ${_PATH}/opt/openssl/lib/libcrypto.dylib
  fi
else
  echoinfo "A salt directory already exists here, not extracting."
fi

mkdir -p ${_PATH}/etc/salt
mkdir -p ${_PATH}/srv/salt

cat <<EOT >${_PATH}/etc/salt/master
root_dir: ${_PATH}
file_root: ${_PATH}/srv/salt
EOT

cat <<EOT >${_PATH}/etc/salt/minion
root_dir: ${_PATH}
master: 127.0.0.1
id: minion
EOT

cat <<EOT >${_PATH}/Saltfile
salt-call:
  local: True
  config_dir: ${_PATH}/etc/salt
  log_file: ${_PATH}/var/log/salt/minion
  cachedir: ${_PATH}/var/cache/salt
  file_root: ${_PATH}/srv/salt

salt-master:
  config_dir: ${_PATH}/etc/salt
  file_root: ${_PATH}/srv/salt

salt-minion:
  config_dir: ${_PATH}/etc/salt
  file_root: ${_PATH}/srv/salt

salt-key:
  config_dir: ${_PATH}/etc/salt

salt:
  config_dir: ${_PATH}/etc/salt
EOT

PATH_MSG="export PATH=${_PATH}"
PATH_MSG+=':$PATH'

echoinfo "Get started with Salt by running the following commands"
echoinfo "Add Salt to current path"
echoinfo "  ${PATH_MSG}"
echoinfo "Use the provided Saltfile"
echoinfo "  export SALT_SALTFILE=${_PATH}/Saltfile"
# very very hacky, remove ASAP
if [[ "${_DARWIN_ARM}" == "1" ]]; then
  echoinfo "Setup HOMEBREW"
  echoinfo "  export HOMEBREW_PREFIX=${_PATH}"
fi

echoinfo "Create Salt states in ${_PATH}/srv/salt"

if [[ "${_FULL}" == "1" ]]; then

  export PATH="${_PATH}:$PATH"
  export SALT_SALTFILE="${_PATH}/Saltfile"
  # very very hacky, remove ASAP
  if [[ "${_DARWIN_ARM}" == "1" ]]; then
    export HOMEBREW_PREFIX=${_PATH}
  fi
  echoinfo "Starting salt-master"
  salt-master -d -c ${_PATH}/etc/salt
  sleep 5
  echoinfo "Starting salt-minion"
  salt-minion -d -c ${_PATH}/etc/salt

echoinfo "Run salt-key -L to see pending minion keys"
echoinfo "Run salt-key -a minion to accept the pending minion key"

fi
