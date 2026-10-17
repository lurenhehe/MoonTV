#!/usr/bin/env python3
"""Send a saved UTF-8 shell script over SSH, normalizing Windows newlines."""
import pathlib
import subprocess
import sys

script = pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig').replace('\r\n', '\n')
subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15',
    'root@91.213.186.133', 'bash -se'], input=script.encode(), check=True)
