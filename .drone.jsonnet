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

local git_distros = [
  'arch',
  'amazon-1',
  'amazon-2',
  'centos-6',
  'centos-7',
  'debian-8',
  'debian-9',
  'fedora-28',
  'fedora-29',
  'opensuse-15',
  'opensuse-42',
  'ubuntu-1404',
  'ubuntu-1604',
  'ubuntu-1804',
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
  name: distro,

  steps: [
    {
      name: suite,
      privileged: true,
      image: 'saltstack/drone-plugin-kitchen',
      settings: {
        target: std.format('%s-%s', [suite, distro]),
        requirements: 'tests/requirements.txt',
      },
    }
    for suite in git_suites + stable_suites
  ],
  depends_on: [
    'run-shellcheck',
  ],
};


[
  Shellcheck(),
] + [
  Build(distro)
  for distro in stable_distros
]
