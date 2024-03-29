import logging

import ptscripts

ptscripts.register_tools_module("tools.pre_commit")
ptscripts.register_tools_module("tools.release")

for name in ("boto3", "botocore", "urllib3"):
    logging.getLogger(name).setLevel(logging.INFO)
