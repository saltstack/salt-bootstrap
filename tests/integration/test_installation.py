# -*- coding: utf-8 -*-
import json
import os
import pytest
import logging
import pprint
from contextlib import nullcontext

log = logging.getLogger(__name__)


def selected_context_manager(host):
    if "windows" in os.environ.get("KITCHEN_INSTANCE"):
        return nullcontext()
    return host.sudo()


def test_ping(host):
    with selected_context_manager(host):
        assert host.salt("test.ping", "--timeout=120")


def test_target_python_version(host, target_python_version):
    with selected_context_manager(host):
        ret = host.salt("grains.item", "pythonversion", "--timeout=120")
        assert ret["pythonversion"][0] == target_python_version


def test_target_salt_version(host, target_salt_version):
    with selected_context_manager(host):
        ret = host.salt("grains.item", "saltversion", "--timeout=120")
        if target_salt_version.endswith(".0"):
            assert ret["saltversion"] == ".".join(target_salt_version.split(".")[:-1])
        else:
            assert ret["saltversion"].startswith(target_salt_version)
