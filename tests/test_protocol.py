"""Wire format tests.

These lock in the exact byte sequences of the rmate protocol as
CotMate speaks them, plus the parser that reads them back.

Run from the repo root:

    python3 -m unittest discover tests -v
"""

import socket
import unittest

from tests import cotmate


class SocketPairTestCase(unittest.TestCase):
    """Base class providing a connected socket pair."""

    def setUp(self):
        self.a, self.b = socket.socketpair()
        self.addCleanup(self.a.close)
        self.addCleanup(self.b.close)


class TestReadLine(SocketPairTestCase):

    def test_reads_until_lf(self):
        self.a.sendall(b"hello\n")
        self.assertEqual(cotmate.read_line(self.b), "hello")

    def test_strips_trailing_cr(self):
        self.a.sendall(b"hello\r\n")
        self.assertEqual(cotmate.read_line(self.b), "hello")

    def test_returns_empty_for_blank_line(self):
        self.a.sendall(b"\n")
        self.assertEqual(cotmate.read_line(self.b), "")

    def test_eof_raises_eoferror(self):
        self.a.close()
        with self.assertRaises(EOFError):
            cotmate.read_line(self.b)

    def test_utf8(self):
        self.a.sendall("héllo\n".encode("utf-8"))
        self.assertEqual(cotmate.read_line(self.b), "héllo")


class TestReadCommand(SocketPairTestCase):

    def test_bare_dot_does_not_block(self):
        """Regression: the handshake separator must return immediately.

        The bash rmate client sends a bare '.' with no following blank
        line; a naive parser waits forever for a terminator that never
        arrives.
        """
        self.a.sendall(b".\n")
        command, headers, body = cotmate.read_command(self.b)
        self.assertEqual(command, ".")
        self.assertEqual(headers, {})
        self.assertEqual(body, b"")

    def test_open_with_body(self):
        payload = b"hello world"
        self.a.sendall(
            b"open\n"
            b"token: /tmp/foo\n"
            b"display-name: host:/tmp/foo\n"
            b"data: 11\n"
            + payload
            + b"\n"
        )

        command, headers, body = cotmate.read_command(self.b)

        self.assertEqual(command, "open")
        self.assertEqual(headers["token"], "/tmp/foo")
        self.assertEqual(headers["display-name"], "host:/tmp/foo")
        self.assertEqual(body, payload)

    def test_body_split_across_recv_calls(self):
        """TCP fragmentation must not corrupt the body."""
        self.a.sendall(b"open\ntoken: t\ndata: 5\nhe")
        self.a.sendall(b"ll")
        self.a.sendall(b"o\n")

        command, headers, body = cotmate.read_command(self.b)

        self.assertEqual(command, "open")
        self.assertEqual(body, b"hello")

    def test_blank_body(self):
        self.a.sendall(b"open\ntoken: t\ndata: 0\n\n")

        command, headers, body = cotmate.read_command(self.b)

        self.assertEqual(command, "open")
        self.assertEqual(body, b"")

    def test_header_value_preserves_internal_colons(self):
        self.a.sendall(
            b"open\n"
            b"display-name: host:/path/to/file\n"
            b"data: 0\n"
            b"\n"
        )

        command, headers, body = cotmate.read_command(self.b)

        self.assertEqual(headers["display-name"], "host:/path/to/file")