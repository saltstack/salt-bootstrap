# -*- coding: utf-8 -*-
import pytest


def test_ping(host):
    with host.sudo():
        assert host.salt('test.ping')
