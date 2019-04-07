local git_suites = [
  'py2-git-2017-7',
  'py2-git-2018-3',
  'py2-git-2019-2',
  // 'py2-git-develop',  // Don't test against Salt's develop branch. Stability is not assured.
];

local stable_suites = [
  'py2-stable-2017-7',
  'py2-stable-2018-3',
  'py2-stable-2019-2',
];

local distros = [
  { name: 'Arch', slug: 'arch' },
  { name: 'Amazon 1', slug: 'amazon-1' }
  { name: 'Amazon 2', slug: 'amazon-2' },
  { name: 'CentOS 6', slug: 'centos-6' },
  { name: 'CentOS 7', slug: 'centos-7' },
  { name: 'Debian 8', slug: 'debian-8' },
  { name: 'Debian 9', slug: 'debian-9' },
  { name: 'Fedora 28', slug: 'fedora-28' },
  { name: 'Fedora 29', slug: 'fedora-29' },
  { name: 'Opensuse 15.0', slug: 'opensuse-15' },
  { name: 'Opensuse 42.3', slug: 'opensuse-42' },
  { name: 'Ubuntu 14.04', slug: 'ubuntu-1404' },
  { name: 'Ubuntu 16.04', slug: 'ubuntu-1604' },
  { name: 'Ubuntu 18.04', slug: 'ubuntu-1804' },
];

local stable_distros = [
  'amazon-1',
  'amazon-2',
  'centos-6',
  'centos-7',
  'debian-8',
  'debian-9',
  'ubuntu-1404',
  'ubuntu-1604',
  'ubuntu-1804',
];

local Shellcheck() = {
  kind: 'pipeline',
  name: 'run-shellcheck',

  steps: [
    {
      name: 'build',
      image: 'koalaman/shellcheck-alpine',
      commands: [
        'shellcheck -s sh -f checkstyle bootstrap-salt.sh',
      ],
    },
  ],
};


local Build(distro) = {
  kind: 'pipeline',
  name: distro.name,

  local suites = if std.count(stable_distros, distro.slug) > 0 then git_suites + stable_suites else git_suites,

  steps: [
    {
      name: 'throttle-build',
      image: 'alpine',
      commands: [
        "sh -c 't=$(shuf -i 10-60 -n 1); echo Sleeping $t seconds; sleep $t'",
      ],
    },
  ] + [
    {
      name: suite,
      privileged: true,
      image: 'saltstack/drone-plugin-kitchen',
      depends_on: [
        'throttle-build',
      ],
      settings: {
        target: std.format('%s-%s', [suite, distro.slug]),
        requirements: 'tests/requirements.txt',
      },
    }
    for suite in suites
  ],
  depends_on: [
    'run-shellcheck',
  ],
};


[
  Shellcheck(),
] + [
  Build(distro)
  for distro in distros
]
