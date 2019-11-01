local git_suites = [
  { name: 'Py2 2018.3(Git)', slug: 'py2-git-2018-3', depends: [] },
  { name: 'Py2 2019.2(Git)', slug: 'py2-git-2019-2', depends: ['Py2 2018.3(Git)'] },
  // {name: 'Py2 develop(Stable)', slug: 'py2-git-develop'},  // Don't test against Salt's develop branch. Stability is not assured.
];

local git_py3_suites = [
  { name: 'Py3 2018.3(Git)', slug: 'py3-git-2018-3', depends: [] },
  { name: 'Py3 2019.2(Git)', slug: 'py3-git-2019-2', depends: ['Py3 2018.3(Git)'] },
];

local stable_suites = [
  { name: 'Py2 2018.3(Stable)', slug: 'py2-stable-2018-3', depends: ['Py2 2018.3(Git)'] },
  { name: 'Py2 2019.2(Stable)', slug: 'py2-stable-2019-2', depends: ['Py2 2019.2(Git)'] },
];

local stable_py3_suites = [
  { name: 'Py3 2018.3(Stable)', slug: 'py3-stable-2018-3', depends: ['Py3 2018.3(Git)'] },
  { name: 'Py3 2019.2(Stable)', slug: 'py3-stable-2019-2', depends: ['Py3 2019.2(Git)'] },
];

local distros = [
  { name: 'Arch', slug: 'arch', multiplier: 0, depends: [] },
//  { name: 'Amazon 1', slug: 'amazon-1', multiplier: 1, depends: [] },
  { name: 'Amazon 2', slug: 'amazon-2', multiplier: 2, depends: [] },
  { name: 'CentOS 6', slug: 'centos-6', multiplier: 3, depends: [] },
  { name: 'CentOS 7', slug: 'centos-7', multiplier: 4, depends: [] },
  { name: 'CentOS 8', slug: 'centos-8', multiplier: 5, depends: [] },
  { name: 'Debian 8', slug: 'debian-8', multiplier: 6, depends: [] },
  { name: 'Debian 9', slug: 'debian-9', multiplier: 7, depends: [] },
  { name: 'Debian 10', slug: 'debian-10', multiplier: 5, depends: [] },
  { name: 'Fedora 30', slug: 'fedora-30', multiplier: 4, depends: [] },
  { name: 'Fedora 31', slug: 'fedora-31', multiplier: 3, depends: [] },
  { name: 'Opensuse 15.1', slug: 'opensuse-15', multiplier: 2, depends: [] },
  { name: 'Ubuntu 16.04', slug: 'ubuntu-1604', multiplier: 1, depends: [] },
  { name: 'Ubuntu 18.04', slug: 'ubuntu-1804', multiplier: 0, depends: [] },
];

local stable_distros = [
  'amazon-1',
  'amazon-2',
  'centos-6',
  'centos-7',
  'centos-8',
  'debian-8',
  'debian-9',
  'debian-10',
  'fedora-30',
  'ubuntu-1604',
  'ubuntu-1804',
];

local py3_distros = [
  'amazon-2',
  'arch',
  'centos-7',
  'centos-8',
  'debian-9',
  'debian-10',
  'ubuntu-1604',
  'ubuntu-1804',
  'fedora-30',
];

local py2_blacklist = [
  'centos-8',
  'debian-10',
];

local blacklist_2018 = [
  'centos-8',
  'debian-10',
  'amazon-2',
];

local Shellcheck() = {
  kind: 'pipeline',
  name: 'Lint',

  steps: [
    {
      name: 'shellcheck',
      image: 'koalaman/shellcheck-alpine:v0.6.0',
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

  local temp_git_suites = if std.count(py2_blacklist, distro.slug) > 0 then
      []
    else
      git_suites,

  local temp_stable_suites = if std.count(py2_blacklist, distro.slug) > 0 then
      []
    else if std.count(stable_distros, distro.slug) > 0 then
      stable_suites
    else
      [],

  local temp_git_py3_suites = if std.count(py3_distros, distro.slug) < 1 then
      []
    else if std.count(blacklist_2018, distro.slug) > 0 then
      git_py3_suites[1:]
    else if std.count(py3_distros, distro.slug) > 0 then
      git_py3_suites
    else
      [],

  local temp_stable_py3_suites = if std.count(stable_distros, distro.slug) < 1 then
      []
    else if std.count(blacklist_2018, distro.slug) > 0 then
      stable_py3_suites[1:]
    else if std.count(py3_distros, distro.slug) > 0 then
      stable_py3_suites
    else
      [],

  local suites = temp_git_suites + temp_stable_suites + temp_git_py3_suites + temp_stable_py3_suites,

  steps: [
    {
      name: 'throttle-build',
      image: 'alpine',
      commands: [
        std.format(
          "sh -c 't=%(offset)s; echo Sleeping %(offset)s seconds; sleep %(offset)s'",
          { offset: 6 * std.length(suites) * distro.multiplier }
        ),
      ],
    },
    {
      name: 'create',
      image: 'saltstack/drone-salt-bootstrap-testing',
      environment: {
        DOCKER_HOST: 'tcp://docker:2375',
      },
      depends_on: [
        'throttle-build',
      ],
      commands: [
        'bundle install --with docker --without opennebula ec2 windows vagrant',
        "echo 'Waiting for docker to start'",
        'sleep 20',  // give docker enough time to start
        'docker ps -a',
        std.format('bundle exec kitchen create %s', [distro.slug]),
      ],
    },
  ] + [
    {
      name: suite.name,
      image: 'saltstack/drone-salt-bootstrap-testing',
      environment: {
        DOCKER_HOST: 'tcp://docker:2375',
      },
      depends_on: [
        'throttle-build',
        'create',
      ],
      commands: [
        'pip install -U pip',
        'pip install -r tests/requirements.txt',
        'bundle install --with docker --without opennebula ec2 windows vagrant',
        std.format('bundle exec kitchen test %s-%s', [suite.slug, distro.slug]),
      ],
    }
    for suite in suites
  ],
  services: [
    {
      name: 'docker',
      image: 'saltstack/drone-salt-bootstrap-testing',
      privileged: true,
      environment: {},
      command: [
        '--storage-driver=overlay2',
      ],
    },
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
