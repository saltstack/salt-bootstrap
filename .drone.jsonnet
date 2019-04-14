local git_suites = [
  { name: 'Py2 2017.7(Git)', slug: 'py2-git-2017-7' },
  { name: 'Py2 2018.3(Git)', slug: 'py2-git-2018-3' },
  { name: 'Py2 2019.2(Git)', slug: 'py2-git-2019-2' },
  // {name: 'Py2 develop(Stable)', slug: 'py2-git-develop'},  // Don't test against Salt's develop branch. Stability is not assured.
];

local stable_suites = [
  { name: 'Py2 2017.7(Stable)', slug: 'py2-stable-2017-7' },
  { name: 'Py2 2018.3(Stable)', slug: 'py2-stable-2018-3' },
  { name: 'Py2 2019.2(Stable)', slug: 'py2-stable-2019-2' },
];

local distros = [
  { name: 'Arch', slug: 'arch', multiplier: 0 },
  { name: 'Amazon 1', slug: 'amazon-1', multiplier: 1 },
  { name: 'Amazon 2', slug: 'amazon-2', multiplier: 2 },
  { name: 'CentOS 6', slug: 'centos-6', multiplier: 3 },
  { name: 'CentOS 7', slug: 'centos-7', multiplier: 4 },
  { name: 'Debian 8', slug: 'debian-8', multiplier: 5 },
  { name: 'Debian 9', slug: 'debian-9', multiplier: 6 },
  { name: 'Fedora 28', slug: 'fedora-28', multiplier: 7 },
  { name: 'Fedora 29', slug: 'fedora-29', multiplier: 8 },
  { name: 'Opensuse 15.0', slug: 'opensuse-15', multiplier: 9 },
  { name: 'Opensuse 42.3', slug: 'opensuse-42', multiplier: 10 },
  { name: 'Ubuntu 14.04', slug: 'ubuntu-1404', multiplier: 11 },
  { name: 'Ubuntu 16.04', slug: 'ubuntu-1604', multiplier: 12 },
  { name: 'Ubuntu 18.04', slug: 'ubuntu-1804', multiplier: 13 },
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
  name: 'Lint',

  steps: [
    {
      name: 'shellcheck',
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
  node: {
    project: 'open',
  },

  local suites = if std.count(stable_distros, distro.slug) > 0 then git_suites + stable_suites else git_suites,

  steps: [
    {
      name: 'throttle-build',
      image: 'alpine',
      commands: [
        std.format(
          "sh -c 't=%(offset)s; echo Sleeping %(offset)s seconds; sleep %(offset)s'",
          { offset: 5 * std.length(suites) * distro.multiplier }
        ),
      ],
    },
  ] + [
    {
      name: suite.name,
      privileged: true,
      image: 'saltstack/drone-plugin-kitchen',
      depends_on: [
        'throttle-build',
      ],
      settings: {
        target: std.format('%s-%s', [suite.slug, distro.slug]),
        requirements: 'tests/requirements.txt',
      },
    }
    for suite in suites
  ],
  depends_on: [
    'Lint',
  ],
};


[
  Shellcheck(),
] + [
  Build(distro)
  for distro in distros
]
