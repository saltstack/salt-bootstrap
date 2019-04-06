local suites = [
  'py2-git-2017.7',
  'py2-git-2018.3',
  'py2-git-2019.2',
  'py2-git-develop',
  'py2-stable-2017.7',
  'py2-stable-2018.3',
  'py2-stable-2019.2',
];

local distros = [
  { name: 'amazon', version: '1' },
  { name: 'amazon', version: '2' },
  { name: 'centos', version: '6' },
  { name: 'centos', version: '7' },
  { name: 'debian', version: '8' },
  { name: 'debian', version: '9' },
  { name: 'fedora', version: '28' },
  { name: 'fedora', version: '29' },
  { name: 'opensuse', version: '15' },
  { name: 'opensuse', version: '42' },
  { name: 'ubuntu', version: '1404' },
  { name: 'ubuntu', version: '1604' },
  { name: 'ubuntu', version: '1804' },
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

local Build(suite, os, os_version) = {
  kind: 'pipeline',
  name: std.format('%s-%s-%s', [suite, os, os_version]),

  steps: [
    {
      name: 'build',
      privileged: true,
      image: 'saltstack/drone-plugin-kitchen',
      settings: {
        target: std.format('%s-%s-%s', [suite, os, os_version]),
        requirements: 'tests/requirements.txt',
      },
    },
  ],
  depends_on: [
    'run-shellcheck',
  ],
};


[
  Shellcheck(),
] + [
  Build(suite, distro.name, distro.version)
  for distro in distros
  for suite in suites
]
