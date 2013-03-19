'''
This file was copied and adapted from salt's source code
'''

import os
import re
import sys
import platform
# Extend the default list of supported distros. This will be used for the
# /etc/DISTRO-release checking that is part of platform.linux_distribution()
from platform import _supported_dists
_supported_dists += ('arch', 'mageia', 'meego', 'vmware', 'bluewhite64',
                     'slamd64', 'ovs', 'system', 'mint', 'oracle')

_REPLACE_LINUX_RE = re.compile(r'linux', re.IGNORECASE)

# This maps (at most) the first ten characters (no spaces, lowercased) of
# 'osfullname' to the 'os' grain that Salt traditionally uses.
# Please see os_data() and _supported_dists.
# If your system is not detecting properly it likely needs an entry here.
_OS_NAME_MAP = {
    'redhatente': 'RedHat',
    'gentoobase': 'Gentoo',
    'archarm': 'Arch ARM',
    'arch': 'Arch',
    'debian': 'Debian',
    'debiangnu/': 'Debian',
    'fedoraremi': 'Fedora',
    'amazonami': 'Amazon',
    'alt': 'ALT',
    'oracleserv': 'OEL',
}

# Map the 'os' grain to the 'os_family' grain
# These should always be capitalized entries as the lookup comes
# post-_OS_NAME_MAP. If your system is having trouble with detection, please
# make sure that the 'os' grain is capitalized and working correctly first.
_OS_FAMILY_MAP = {
    'Ubuntu': 'Debian',
    'Fedora': 'RedHat',
    'CentOS': 'RedHat',
    'GoOSe': 'RedHat',
    'Scientific': 'RedHat',
    'Amazon': 'RedHat',
    'CloudLinux': 'RedHat',
    'OVS': 'RedHat',
    'OEL': 'RedHat',
    'Mandrake': 'Mandriva',
    'ESXi': 'VMWare',
    'Mint': 'Debian',
    'VMWareESX': 'VMWare',
    'Bluewhite64': 'Bluewhite',
    'Slamd64': 'Slackware',
    'SLES': 'Suse',
    'SUSE Enterprise Server': 'Suse',
    'SUSE Enterprise Server': 'Suse',
    'SLED': 'Suse',
    'openSUSE': 'Suse',
    'SUSE': 'Suse',
    'Solaris': 'Solaris',
    'SmartOS': 'Solaris',
    'Arch ARM': 'Arch',
    'ALT': 'RedHat',
    'Trisquel': 'Debian'
}


def os_data():
    '''
    Return grains pertaining to the operating system
    '''
    grains = {
        'num_gpus': 0,
        'gpus': [],
    }

    # Windows Server 2008 64-bit
    # ('Windows', 'MINIONNAME', '2008ServerR2', '6.1.7601', 'AMD64', 'Intel64 Fam ily 6 Model 23 Stepping 6, GenuineIntel')
    # Ubuntu 10.04
    # ('Linux', 'MINIONNAME', '2.6.32-38-server', '#83-Ubuntu SMP Wed Jan 4 11:26:59 UTC 2012', 'x86_64', '')
    (grains['kernel'], grains['nodename'],
     grains['kernelrelease'], version, grains['cpuarch'], _) = platform.uname()
    if sys.platform.startswith('win'):
        grains['osrelease'] = grains['kernelrelease']
        grains['osversion'] = grains['kernelrelease'] = version
        grains['os'] = 'Windows'
        grains['os_family'] = 'Windows'
        return grains
    elif sys.platform.startswith('linux'):
        # Add lsb grains on any distro with lsb-release
        try:
            import lsb_release
            release = lsb_release.get_distro_information()
            for key, value in release.iteritems():
                grains['lsb_{0}'.format(key.lower())] = value  # override /etc/lsb-release
        except ImportError:
            # if the python library isn't available, default to regex
            if os.path.isfile('/etc/lsb-release'):
                with open('/etc/lsb-release') as ifile:
                    for line in ifile:
                        # Matches any possible format:
                        # DISTRIB_ID="Ubuntu"
                        # DISTRIB_ID='Mageia'
                        # DISTRIB_ID=Fedora
                        # DISTRIB_RELEASE='10.10'
                        # DISTRIB_CODENAME='squeeze'
                        # DISTRIB_DESCRIPTION='Ubuntu 10.10'
                        regex = re.compile('^(DISTRIB_(?:ID|RELEASE|CODENAME|DESCRIPTION))=(?:\'|")?([\w\s\.-_]+)(?:\'|")?')
                        match = regex.match(line.rstrip('\n'))
                        if match:
                            # Adds: lsb_distrib_{id,release,codename,description}
                            grains['lsb_{0}'.format(match.groups()[0].lower())] = match.groups()[1].rstrip()
            elif os.path.isfile('/etc/os-release'):
                # Arch ARM linux
                with open('/etc/os-release') as ifile:
                    # Imitate lsb-release
                    for line in ifile:
                        # NAME="Arch Linux ARM"
                        # ID=archarm
                        # ID_LIKE=arch
                        # PRETTY_NAME="Arch Linux ARM"
                        # ANSI_COLOR="0;36"
                        # HOME_URL="http://archlinuxarm.org/"
                        # SUPPORT_URL="https://archlinuxarm.org/forum"
                        # BUG_REPORT_URL="https://github.com/archlinuxarm/PKGBUILDs/issues"
                        regex = re.compile('^([\w]+)=(?:\'|")?([\w\s\.-_]+)(?:\'|")?')
                        match = regex.match(line.rstrip('\n'))
                        if match:
                            name, value = match.groups()
                            if name.lower() == 'name':
                                grains['lsb_distrib_id'] = value.strip()
            elif os.path.isfile('/etc/altlinux-release'):
                # ALT Linux
                grains['lsb_distrib_id'] = 'altlinux'
                with open('/etc/altlinux-release') as ifile:
                    # This file is symlinked to from:
                    # /etc/fedora-release
                    # /etc/redhat-release
                    # /etc/system-release
                    for line in ifile:
                        # ALT Linux Sisyphus (unstable)
                        comps = line.split()
                        if comps[0] == 'ALT':
                            grains['lsb_distrib_release'] = comps[2]
                            grains['lsb_distrib_codename'] = \
                                comps[3].replace('(', '').replace(')', '')
        # Use the already intelligent platform module to get distro info
        (osname, osrelease, oscodename) = platform.linux_distribution(
            supported_dists=_supported_dists)
        # Try to assign these three names based on the lsb info, they tend to
        # be more accurate than what python gets from /etc/DISTRO-release.
        # It's worth noting that Ubuntu has patched their Python distribution
        # so that platform.linux_distribution() does the /etc/lsb-release
        # parsing, but we do it anyway here for the sake for full portability.
        grains['osfullname'] = grains.get('lsb_distrib_id', osname).strip()
        grains['osrelease'] = grains.get('lsb_distrib_release', osrelease).strip()
        grains['oscodename'] = grains.get('lsb_distrib_codename', oscodename).strip()
        distroname = _REPLACE_LINUX_RE.sub('', grains['osfullname']).strip()
        # return the first ten characters with no spaces, lowercased
        shortname = distroname.replace(' ', '').lower()[:10]
        # this maps the long names from the /etc/DISTRO-release files to the
        # traditional short names that Salt has used.
        grains['os'] = _OS_NAME_MAP.get(shortname, distroname)
    elif grains['kernel'] == 'SunOS':
        grains['os'] = 'Solaris'
        if os.path.isfile('/etc/release'):
            with open('/etc/release', 'r') as fp_:
                rel_data = fp_.read()
                if 'SmartOS' in rel_data:
                    grains['os'] = 'SmartOS'
        #grains.update(_sunos_cpudata(grains))
    elif grains['kernel'] == 'VMkernel':
        grains['os'] = 'ESXi'
    elif grains['kernel'] == 'Darwin':
        grains['os'] = 'MacOS'
    #    grains.update(_bsd_cpudata(grains))
    else:
        grains['os'] = grains['kernel']
    if grains['kernel'] in ('FreeBSD', 'OpenBSD'):
        grains['os'] = grains['kernel']
        grains['os_family'] = grains['os']
        grains['osfullname'] = "{0} {1}".format(grains['kernel'], grains['kernelrelease'])
        grains['osrelease'] = grains['kernelrelease']
    #    grains.update(_bsd_cpudata(grains))
    if not grains['os']:
        grains['os'] = 'Unknown {0}'.format(grains['kernel'])
        grains['os_family'] = 'Unknown'
    else:
        # this assigns family names based on the os name
        # family defaults to the os name if not found
        grains['os_family'] = _OS_FAMILY_MAP.get(grains['os'], grains['os'])

    return grains

GRAINS = os_data()

if __name__ == '__main__':
    import pprint
    pprint.pprint(GRAINS)
