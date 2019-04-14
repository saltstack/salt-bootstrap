local git_suites = [
  { name: 'Py2 2017.7(Git)', slug: 'py2-git-2017-7', depends: [] },
  { name: 'Py2 2018.3(Git)', slug: 'py2-git-2018-3', depends: ['Py2 2017.7(Git)'] },
  { name: 'Py2 2019.2(Git)', slug: 'py2-git-2019-2', depends: ['Py2 2018.3(Git)'] },
  // {name: 'Py2 develop(Stable)', slug: 'py2-git-develop'},  // Don't test against Salt's develop branch. Stability is not assured.
];

local stable_suites = [
  { name: 'Py2 2017.7(Stable)', slug: 'py2-stable-2017-7', depends: ['Py2 2017.7(Git)'] },
  { name: 'Py2 2018.3(Stable)', slug: 'py2-stable-2018-3', depends: ['Py2 2018.3(Git)'] },
  { name: 'Py2 2019.2(Stable)', slug: 'py2-stable-2019-2', depends: ['Py2 2019.2(Git)'] },
];

local distros = [
  { name: 'Arch', slug: 'arch', multiplier: 0, depends: [] },
  { name: 'Amazon 1', slug: 'amazon-1', multiplier: 1, depends: [] },
  { name: 'Amazon 2', slug: 'amazon-2', multiplier: 2, depends: [] },
  { name: 'CentOS 6', slug: 'centos-6', multiplier: 3, depends: [] },
  { name: 'CentOS 7', slug: 'centos-7', multiplier: 4, depends: [] },
  { name: 'Debian 8', slug: 'debian-8', multiplier: 5, depends: [] },
  { name: 'Debian 9', slug: 'debian-9', multiplier: 6, depends: [] },
  { name: 'Fedora 28', slug: 'fedora-28', multiplier: 7, depends: ['Debian 9'] },
  { name: 'Fedora 29', slug: 'fedora-29', multiplier: 8, depends: ['Debian 8'] },
  { name: 'Opensuse 15.0', slug: 'opensuse-15', multiplier: 9, depends: ['CentOS 7'] },
  { name: 'Opensuse 42.3', slug: 'opensuse-42', multiplier: 10, depends: ['CentOS 6'] },
  { name: 'Ubuntu 14.04', slug: 'ubuntu-1404', multiplier: 11, depends: ['Amazon 2'] },
  { name: 'Ubuntu 16.04', slug: 'ubuntu-1604', multiplier: 12, depends: ['Amazon 1'] },
  { name: 'Ubuntu 18.04', slug: 'ubuntu-1804', multiplier: 13, depends: ['Arch'] },
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
      name: suite.name,
      privileged: true,
      image: 'saltstack/drone-plugin-kitchen',
      depends_on: [
        'clone',
      ] + suite.depends,
      settings: {
        target: std.format('%s-%s', [suite.slug, distro.slug]),
        requirements: 'tests/requirements.txt',
      },
    }
    for suite in suites
  ],
  depends_on: [
    'Lint',
  ] + distro.depends,
};


[
  Shellcheck(),
] + [
  Build(distro)
  for distro in distros
]
