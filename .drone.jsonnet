local Build(os, os_version) = {
  kind: 'pipeline',
  name: 'build-' + os + '-' + os_version,
  steps: [
    {
      name: 'build',
      image: 'saltstack/drone-plugin-kitchen',
      privileged: true,
      settings: {
        target: os + '-' + os_version,
        requirements: 'tests/requirements.txt',
      },
      when: { event: ['pull_request'] },
      },
  ],
  depends_on: [
    'run-shellcheck'
  ]
};

local Shellcheck() = {
  kind: 'pipeline',
  name: 'run-shellcheck',
  steps: [
    {
      name: 'run-shellcheck',
      image: 'koalaman/shellcheck-alpine',
      commands: [
        'shellcheck -s sh -f checkstyle bootstrap-salt.sh',
      ],
       when: { event: ['pull_request'] }
    }
  ]
};
        
local distros = [
  { name: 'centos', version: '6' },
  { name: 'centos', version: '7' },
  { name: 'debian', version: '8' },
  { name: 'debian', version: '9' },
  { name: 'ubuntu', version: '1404' },
#  { name: 'ubuntu', version: '1604' },
  { name: 'ubuntu', version: '1804' },
];
        
[
  Build(distro.name, distro.version)
  for distro in distros
] + [
  Shellcheck()
] 
