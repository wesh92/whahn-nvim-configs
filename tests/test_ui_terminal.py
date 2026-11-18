"""Offline PTY protocol/cleanup regressions; no editor or plugins are started."""
import contextlib
import io
import itertools
import json
import os
import runpy
import signal
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

HARNESS = Path(__file__).with_name("ui_terminal.py")
STATUS = (b"\x1b[5n", b"\x1b[0n")
BACKGROUND = (b"\x1b]11;?\x07", b"\x1b]11;rgb:1e1e/1e1e/2e2e\x1b\\")
PROBES = [
    STATUS,
    (b"\x1b[6n", b"\x1b[1;1R"),
    (b"\x1b[c", b"\x1b[?1;2c"),
    (b"\x1b[>c", b"\x1b[>0;0;0c"),
    BACKGROUND,
    (b"\x1b]10;?\x1b\\", b"\x1b]10;rgb:eeee/eeee/eeee\x1b\\"),
    (b"\x1b]11;?\x1b\\", BACKGROUND[1]),
    (b"\x1b]10;?\x07", b"\x1b]10;rgb:eeee/eeee/eeee\x1b\\"),
]


@unittest.skipUnless(sys.platform == "linux", "the real-PTY harness requires Linux")
class TerminalHarnessTests(unittest.TestCase):
    def run_harness(self, chunks=(), *, leader_exit: int | None = 0, ignore_term=False,
                    signal_error=None, close_error=None, read_error=None, vanish_on=None):
        temp = tempfile.TemporaryDirectory(prefix="nvim-pty-regression-", dir=os.environ.get("TMPDIR"))
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        (root / "result.json").write_text(json.dumps({"passed": True, "checks": []}))
        process = mock.Mock(pid=123456, returncode=leader_exit)
        process.poll.side_effect = lambda: process.returncode

        def wait(timeout):
            process.returncode = 0
            return 0

        process.wait.side_effect = wait
        signals = []
        alive = True

        def killpg(pgid, sig):
            nonlocal alive
            signals.append((pgid, sig))
            if signal_error is not None:
                raise signal_error
            if sig == vanish_on:
                raise ProcessLookupError()
            if not alive:
                raise ProcessLookupError()
            if sig == getattr(signal, "SIGKILL") or (sig == signal.SIGTERM and not ignore_term):
                alive = False

        def close(fd):
            if fd == 101 and close_error is not None:
                raise close_error

        with contextlib.ExitStack() as stack:
            def patch(target, **kwargs):
                return stack.enter_context(mock.patch(target, **kwargs))

            patch("sys.argv", new=[str(HARNESS)])
            stack.enter_context(mock.patch.dict(os.environ, XDG_CACHE_HOME=str(root)))
            patch("tempfile.mkdtemp", return_value=str(root))
            patch("pty.openpty", return_value=(101, 102))
            patch("fcntl.ioctl")
            popen = patch("subprocess.Popen", return_value=process)
            patch("select.select", return_value=([101], [], []))
            patch("os.read", side_effect=[*chunks, read_error if read_error is not None else b""])
            writes = patch("os.write")
            closes = patch("os.close", side_effect=close)
            patch("os.killpg", side_effect=killpg)
            patch("time.monotonic", side_effect=itertools.count())
            patch("time.sleep")
            output = stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            error = None
            try:
                runpy.run_path(str(HARNESS), run_name="__main__")
            except Exception as exc:
                error = exc
        return SimpleNamespace(root=root, process=process, error=error, signals=signals,
                               writes=writes.call_args_list, closes=closes.call_args_list,
                               popen=popen, output=output.getvalue())

    def test_status_before_osc_in_one_read_is_not_discarded(self):
        result = self.run_harness([STATUS[0] + BACKGROUND[0]])
        self.assertIsNone(result.error)
        self.assertEqual(result.writes, [mock.call(101, STATUS[1]), mock.call(101, BACKGROUND[1])])
        self.assertEqual(json.loads(result.output)["terminal_queries_answered"], 2)

    def test_mixed_repeated_query_types_are_answered_in_wire_order(self):
        probes = PROBES + [STATUS, BACKGROUND, STATUS]
        result = self.run_harness([b"screen" + b"text".join(query for query, _ in probes)])
        self.assertIsNone(result.error)
        self.assertEqual(result.writes, [mock.call(101, reply) for _, reply in probes])
        self.assertEqual(json.loads(result.output)["terminal_queries_answered"], len(probes))

    def test_incomplete_tail_is_preserved_after_complete_mixed_queries(self):
        result = self.run_harness([STATUS[0] + BACKGROUND[0] + b"\x1b]10;?\x1b", b"\\"])
        self.assertIsNone(result.error)
        self.assertEqual(result.writes, [mock.call(101, reply) for _, reply in
                                        [STATUS, BACKGROUND, PROBES[5]]])

    def test_every_supported_query_can_be_split_at_every_byte(self):
        for query, reply in PROBES:
            for split in range(1, len(query)):
                with self.subTest(query=query, split=split):
                    result = self.run_harness([b"x" * 1024 + query[:split], query[split:]])
                    self.assertIsNone(result.error)
                    self.assertEqual(result.writes, [mock.call(101, reply)])

    def test_reaped_leader_does_not_skip_owned_group_termination(self):
        result = self.run_harness(leader_exit=0)
        self.assertIsNone(result.error)
        self.assertIn((123456, signal.SIGTERM), result.signals)
        self.assertTrue(result.popen.call_args.kwargs["start_new_session"])
        self.assertTrue(all(pgid == result.process.pid for pgid, _ in result.signals))

    def test_reaped_leader_does_not_skip_kill_of_term_resistant_descendants(self):
        result = self.run_harness(leader_exit=0, ignore_term=True)
        self.assertIsNone(result.error)
        signals = [sig for _, sig in result.signals if sig]
        self.assertEqual(signals, [signal.SIGTERM, getattr(signal, "SIGKILL")])
        self.assertLess(len(result.signals), 20, "cleanup must be bounded")
        self.assertTrue(all(pgid == result.process.pid for pgid, _ in result.signals))

    def test_disappeared_group_is_harmless(self):
        for sig in (signal.SIGTERM, 0, getattr(signal, "SIGKILL")):
            with self.subTest(vanish_on=sig):
                read_error = RuntimeError("read failed")
                result = self.run_harness(leader_exit=None, ignore_term=True,
                                          vanish_on=sig, read_error=read_error)
                self.assertIs(result.error, read_error)
                self.assertIn(mock.call(101), result.closes)
                self.assertEqual((result.root / "transcript.log").read_bytes(), b"")

    def test_signal_failure_still_closes_master_and_persists_transcript(self):
        result = self.run_harness([b"captured output"], leader_exit=None,
                                  signal_error=PermissionError("signal denied"),
                                  read_error=RuntimeError("read failed"))
        self.assertIsInstance(result.error, PermissionError)
        self.assertIn(mock.call(101), result.closes)
        self.assertEqual((result.root / "transcript.log").read_bytes(), b"captured output")

    def test_close_failure_still_persists_transcript(self):
        result = self.run_harness([b"captured output"], close_error=OSError("close failed"))
        self.assertIsInstance(result.error, OSError)
        self.assertEqual((result.root / "transcript.log").read_bytes(), b"captured output")


if __name__ == "__main__":
    unittest.main(verbosity=2)
