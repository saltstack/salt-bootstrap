import os
import pytest
import testinfra

if os.environ.get('KITCHEN_USERNAME') == 'vagrant':
    if 'windows' in os.environ.get('KITCHEN_INSTANCE'):
        test_host = testinfra.get_host('winrm://{KITCHEN_USERNAME}:{KITCHEN_PASSWORD}@{KITCHEN_HOSTNAME}:{KITCHEN_PORT}'.format(**os.environ), no_ssl=True)
    else:
        test_host = testinfra.get_host('paramiko://{KITCHEN_USERNAME}@{KITCHEN_HOSTNAME}:{KITCHEN_PORT}'.format(**os.environ),
                                       ssh_identity_file=os.environ.get('KITCHEN_SSH_KEY'))
else:
    test_host = testinfra.get_host('docker://{KITCHEN_USERNAME}@{KITCHEN_CONTAINER_ID}'.format(**os.environ))


@pytest.fixture
def host():
    return test_host
