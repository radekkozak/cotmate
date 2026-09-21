"""DocumentRegistry semantics and Session dispatch."""

import pathlib
import shutil
import socket
import tempfile
import unittest
from unittest import mock

from tests import cotmate


class FakeDoc:
    """Stand-in for a RemoteDocument in registry tests."""

    def __init__(self):
        self.closed = False


class TestDocumentRegistry(unittest.TestCase):

    def setUp(self):
        self.reg = cotmate.DocumentRegistry()
        self.key = ("host", "/tmp/foo.txt")

    def test_lookup_returns_none_for_unknown_key(self):
        self.assertIsNone(self.reg.lookup(self.key))

    def test_try_register_succeeds_when_key_free(self):
        doc = FakeDoc()

        self.assertTrue(self.reg.try_register(self.key, doc))
        self.assertIs(self.reg.lookup(self.key), doc)

    def test_try_register_fails_when_live_doc_present(self):
        first = FakeDoc()
        second = FakeDoc()

        self.reg.try_register(self.key, first)

        self.assertFalse(self.reg.try_register(self.key, second))
        # First doc is still the registered one.
        self.assertIs(self.reg.lookup(self.key), first)

    def test_try_register_succeeds_after_doc_closed(self):
        first = FakeDoc()
        second = FakeDoc()

        self.reg.try_register(self.key, first)
        first.closed = True

        self.assertTrue(self.reg.try_register(self.key, second))
        self.assertIs(self.reg.lookup(self.key), second)

    def test_unregister_only_removes_matching_doc(self):
        registered = FakeDoc()
        impostor = FakeDoc()

        self.reg.try_register(self.key, registered)

        # Trying to unregister a different doc must be a no-op.
        self.reg.unregister(self.key, impostor)
        self.assertIs(self.reg.lookup(self.key), registered)

        # Unregistering the right doc succeeds.
        self.reg.unregister(self.key, registered)
        self.assertIsNone(self.reg.lookup(self.key))


class SessionTestCase(unittest.TestCase):

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        # noinspection PyTypeChecker
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

        self.config = cotmate.Config(base_dir=self.tmp)
        self.registry = cotmate.DocumentRegistry()

        self.client, self.server = socket.socketpair()
        self.addCleanup(self.client.close)
        self.addCleanup(self.server.close)

        self.session = cotmate.Session(
            self.server,
            ("127.0.0.1", 12345),
            self.config,
            self.registry,
        )
        self.addCleanup(self.session.close_all)

    @staticmethod
    def open_headers(token):
        return {
            "token": token,
            "display-name": f"host:{token}",
            "real-path": token,
        }


class TestDuplicateOpen(SessionTestCase):

    def test_second_open_same_path_gets_close(self):
        key = ("host", "/tmp/foo.txt")
        self.registry.try_register(key, FakeDoc())

        self.session.handle_command(
            "open", self.open_headers("/tmp/foo.txt"), b"hello"
        )

        self.client.settimeout(1.0)
        response = self.client.recv(4096)

        self.assertIn(b"close", response)
        self.assertIn(b"token: /tmp/foo.txt", response)

    def test_second_open_does_not_write_mirror_file(self):
        key = ("host", "/tmp/foo.txt")
        self.registry.try_register(key, FakeDoc())

        self.session.handle_command(
            "open", self.open_headers("/tmp/foo.txt"), b"hello"
        )

        mirror = self.config.mirrors_dir / "host" / "tmp" / "foo.txt"
        self.assertFalse(mirror.exists())

    def test_open_with_different_path_is_accepted(self):
        key = ("host", "/tmp/foo.txt")
        self.registry.try_register(key, FakeDoc())

        with mock.patch.object(
                cotmate, "find_cot", return_value="/fake/cot"
        ), mock.patch("subprocess.Popen"):
            self.session.handle_command(
                "open", self.open_headers("/tmp/other.txt"), b"hi"
            )

        # No close should have been sent.
        self.client.settimeout(0.3)
        with self.assertRaises(socket.timeout):
            self.client.recv(4096)

        # The new doc is registered.
        self.assertIsNotNone(self.registry.lookup(("host", "/tmp/other.txt")))


class TestSessionDispatch(SessionTestCase):

    def test_bare_dot_produces_no_output(self):
        self.session.handle_command(".", {}, b"")

        self.client.settimeout(0.3)
        with self.assertRaises(socket.timeout):
            self.client.recv(4096)

    def test_unknown_command_produces_no_output(self):
        self.session.handle_command("frobnicate", {}, b"")

        self.client.settimeout(0.3)
        with self.assertRaises(socket.timeout):
            self.client.recv(4096)


class TestHelpers(unittest.TestCase):

    def test_safe_host_name_strips_port(self):
        self.assertEqual(
            cotmate.safe_host_name("myhost:/path/to/file"),
            "myhost",
        )

    def test_safe_host_name_sanitises_specials(self):
        self.assertEqual(
            cotmate.safe_host_name("my host!:/path"),
            "my_host_",
        )

    def test_safe_host_name_preserves_common_chars(self):
        self.assertEqual(
            cotmate.safe_host_name("my.host-name_1:/x"),
            "my.host-name_1",
        )

    def test_cleanup_stale_mirrors_removes_files_but_keeps_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            mirrors = pathlib.Path(tmp) / "mirrors"
            nested = mirrors / "host" / "sub"
            nested.mkdir(parents=True)

            (mirrors / "top.txt").write_text("x")
            (nested / "deep.txt").write_text("y")

            cotmate.cleanup_stale_mirrors(mirrors)

            self.assertTrue(mirrors.exists())
            # No files should remain anywhere under mirrors/.
            remaining = list(mirrors.rglob("*"))
            self.assertEqual(remaining, [])

    def test_environment_report_has_expected_shape(self):
        report = cotmate.environment_report()
        self.assertIn("Python", report)
        self.assertIn("macOS", report)

    def test_macos_codename_known_releases(self):
        self.assertEqual(cotmate.macos_codename("12.7.6"), "Monterey")
        self.assertEqual(cotmate.macos_codename("14.5"), "Sonoma")
        self.assertEqual(cotmate.macos_codename("26.0"), "Tahoe")

    def test_macos_codename_unknown_release(self):
        self.assertEqual(cotmate.macos_codename("99.0"), "")
        self.assertEqual(cotmate.macos_codename(""), "")
