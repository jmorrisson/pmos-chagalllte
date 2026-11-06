#!/usr/bin/env python3
"""Make pmb/chroot/binfmt.py registration dash-safe.

pmbootstrap registers qemu binfmt entries via `sh -c 'echo "...\\xHH..." > register'`.
On hosts where /bin/sh is dash (Ubuntu/Debian), echo does not interpret \\xHH
escapes, so the kernel receives literal backslash text and the binfmt magic is
broken. This patch writes the registration string as real bytes via a temp
file instead. Idempotent; safe on any host.

Usage: python3 binfmt_patch.py /path/to/pmb/chroot/binfmt.py
"""
import sys

OLD = '''    pmb.helpers.run.root(["sh", "-c", 'echo "' + code + '" > ' + register])'''

NEW = '''    # dash-safe: write registration bytes via temp file (echo on dash does
    # not interpret \\xHH escapes, breaking the binfmt magic)
    code_bytes = code.encode("latin-1").decode("unicode_escape").encode("latin-1")
    tmpfile = "/tmp/pmbootstrap-binfmt-" + arch_qemu
    with open(tmpfile, "wb") as handle:
        handle.write(code_bytes)
    pmb.helpers.run.root(["sh", "-c", "cat " + tmpfile + " > " + register])'''

for p in sys.argv[1:]:
    try:
        s = open(p).read()
    except FileNotFoundError:
        print("missing:", p)
        continue
    if OLD in s:
        open(p, "w").write(s.replace(OLD, NEW))
        print("patched:", p)
    elif "pmbootstrap-binfmt-" in s:
        print("already patched:", p)
    else:
        print("pattern not found:", p)
