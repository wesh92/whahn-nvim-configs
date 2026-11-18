"""Linux real-PTY UI check; answer terminal probes, retain JSON/transcript."""
import argparse
import errno
import json
import os
import re
import select
import signal
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

if sys.platform == "linux":
    import fcntl
    import pty
    import termios
else:
    raise SystemExit("This real-PTY harness requires Linux; run it in the dev container.")

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--nvim", default="nvim", help="editor executable (use the pinned .local/bin/nvim)")
args = parser.parse_args()
cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
cache.mkdir(parents=True, exist_ok=True)
root = Path(tempfile.mkdtemp(prefix="nvim-ui-", dir=cache))
env = dict(os.environ, NVIM_UI_RESULT=str(root / "result.json"), TERM="xterm-256color", COLORTERM="truecolor")
master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
command = [args.nvim, "-i", "NONE", "+lua vim.defer_fn(function() dofile(vim.fn.stdpath('config') .. '/tests/ui.lua') end, 1000)"]
process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=env, start_new_session=True)
# start_new_session owns this group even after poll() reaps its leader.
owned_pgid = process.pid
os.close(slave)
transcript = bytearray()
pending = b""
answered = 0
queries = [
    (re.compile(rb"\x1b\](10|11);\?(?:\x07|\x1b\\)"), None),
    # Neovim 0.12 waits for the DSR status acknowledgement, not just OSC 11.
    (re.compile(rb"\x1b\[5n"), b"\x1b[0n"),
    (re.compile(rb"\x1b\[6n"), b"\x1b[1;1R"),
    (re.compile(rb"\x1b\[c"), b"\x1b[?1;2c"),
    (re.compile(rb"\x1b\[>c"), b"\x1b[>0;0;0c"),
]
try:
    deadline = time.monotonic() + 45
    while time.monotonic() < deadline:
        ready, _, _ = select.select([master], [], [], 0.1)
        if ready:
            try:
                chunk = os.read(master, 65536)
            except OSError as exc:
                if exc.errno == errno.EIO:
                    break
                raise
            if not chunk:
                break
            transcript.extend(chunk)
            pending += chunk
            while True:
                matches = [(match, response) for pattern, response in queries
                           if (match := pattern.search(pending))]
                if not matches:
                    break
                # Consume wire order, not pattern order: later OSCs must not eat DSRs.
                match, response = min(matches, key=lambda item: item[0].start())
                if response is None:
                    # Actual terminal response, not a mocked Neovim UI.
                    rgb = b"eeee/eeee/eeee" if match[1] == b"10" else b"1e1e/1e1e/2e2e"
                    reply = b"\x1b]" + match[1] + b";rgb:" + rgb + b"\x1b\\"
                else:
                    reply = response
                os.write(master, reply)
                answered += 1
                pending = pending[match.end():]
            # Every supported probe is shorter than this retained incomplete tail.
            pending = pending[-512:]
        elif process.poll() is not None:
            break
    if process.poll() is None:
        process.wait(timeout=3)
finally:
    try:
        try:
            os.killpg(owned_pgid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        else:
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                process.poll()  # Reap the leader, but wait on the whole owned group.
                try:
                    os.killpg(owned_pgid, 0)
                except ProcessLookupError:
                    break
                time.sleep(0.05)
            else:
                try:
                    os.killpg(owned_pgid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        process.wait(timeout=3)
    finally:
        try:
            os.close(master)
        finally:
            (root / "transcript.log").write_bytes(transcript)

result_path = root / "result.json"
assert result_path.is_file(), f"UI check did not write results; inspect {root} (exit {process.returncode})"
result = json.loads(result_path.read_text())
print(json.dumps({"result_dir": str(root), "editor_exit": process.returncode,
                  "terminal_queries_answered": answered, **result}, indent=2))
assert process.returncode == 0 and result["passed"], f"UI checks failed: {root}"
assert b"E1568" not in transcript, f"terminal background query was not answered: {root}"
