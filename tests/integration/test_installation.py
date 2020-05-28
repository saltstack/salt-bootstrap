# -*- coding: utf-8 -*-
import json
import pytest
import logging
import pprint

log = logging.getLogger(__name__)


def test_ping(host):
    with host.sudo():
        assert host.salt('test.ping', '--timeout=120')


def test_target_python_version(host, target_python_version):
    with host.sudo():
        ret = host.salt('grains.item', 'pythonversion', '--timeout=120')
        assert ret["pythonversion"][0] == target_python_version


def test_target_salt_version(host, target_salt_version):
    with host.sudo():
        ret = host.salt('grains.item', 'saltversion', '--timeout=120')
        assert ret["saltversion"].startswith(target_salt_version)
