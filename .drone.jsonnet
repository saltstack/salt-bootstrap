local distros = [
  { name: 'amazon', version: '1' },
  { name: 'amazon', version: '2' },
#  { name: 'centos', version: '6' },
  { name: 'centos', version: '7' },
  { name: 'debian', version: '8' },
  { name: 'debian', version: '9' },
#  { name: 'ubuntu', version: '1404' },
#  { name: 'ubuntu', version: '1604' },
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
       when: { event: ['pull_request'] }
    }
  ]
};

local Build(os, os_version) = {
  kind: 'pipeline',
  name: std.format('build-%s-%s', [os, os_version]),
        
  steps: [
    {
      name: 'build',
      privileged: true,
      image: 'saltstack/drone-plugin-kitchen',
      settings: {
        target: std.format('%s-%s', [os, os_version]),
        requirements: 'tests/requirements.txt',
      },
      when: { event: ['pull_request'] },
      },
  ],
  depends_on: [
    'run-shellcheck'
  ]
};
        


[Shellcheck()] + [Build(distro.name, distro.version)for distro in distros]
