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
  // { name: 'Amazon 1', slug: 'amazon-1', multiplier: 1, depends: [] },
  // { name: 'Amazon 2', slug: 'amazon-2', multiplier: 2, depends: [] },
  { name: 'CentOS 6', slug: 'centos-6', multiplier: 3, depends: [] },
  { name: 'CentOS 7', slug: 'centos-7', multiplier: 4, depends: [] },
  { name: 'Debian 8', slug: 'debian-8', multiplier: 5, depends: [] },
  { name: 'Debian 9', slug: 'debian-9', multiplier: 6, depends: [] },
  { name: 'Fedora 28', slug: 'fedora-28', multiplier: 6, depends: [] },
  { name: 'Fedora 29', slug: 'fedora-29', multiplier: 5, depends: [] },
  { name: 'Opensuse 15.0', slug: 'opensuse-15', multiplier: 4, depends: [] },
  { name: 'Opensuse 42.3', slug: 'opensuse-42', multiplier: 3, depends: [] },
  { name: 'Ubuntu 16.04', slug: 'ubuntu-1604', multiplier: 1, depends: [] },
  { name: 'Ubuntu 18.04', slug: 'ubuntu-1804', multiplier: 0, depends: [] },
];

local stable_distros = [
  'amazon-1',
  'amazon-2',
  'centos-6',
  'centos-7',
  'debian-8',
  'debian-9',
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
    {
      name: std.format('Converge %s', [distro.name]),
      image: 'docker:edge-dind',
      environment: {
        DOCKER_HOST: 'tcp://docker:2375',
      },
      depends_on: [
        'throttle-build',
      ],
      commands: [
        'apk --update add wget python python-dev py-pip git ruby-bundler ruby-rdoc ruby-dev gcc ruby-dev make libc-dev openssl-dev libffi-dev',
        'gem install bundler',
        'bundle install --with docker --without opennebula ec2 windows vagrant',
        "echo 'Waiting for docker to start'",
        'sleep 10',  // give docker enough time to start
        'docker ps -a',
        std.format('bundle exec kitchen converge -c %s %s', [std.length(suites), distro.slug]),
      ],
    },
  ] + [
    {
      name: suite.name,
      image: 'docker:edge-dind',
      environment: {
        DOCKER_HOST: 'tcp://docker:2375',
      },
      depends_on: [
        'throttle-build',
        std.format('Converge %s', [distro.name]),
      ],
      commands: [
        'apk --update add wget python python-dev py-pip git ruby-bundler ruby-rdoc ruby-dev gcc ruby-dev make libc-dev openssl-dev libffi-dev',
        'gem install bundler',
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
      image: 'docker:edge-dind',
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
