"""RemoteDocument lifecycle and send_save wire format."""

import pathlib
import shutil
import socket
import tempfile
import unittest

from tests import cotmate


class DocumentTestCase(unittest.TestCase):
    """Base class providing a temp Config and a socket pair."""

    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

        self.config = cotmate.Config(
            host="127.0.0.1",
            port=0,
            base_dir=self.tmp,
        )
        self.registry = cotmate.DocumentRegistry()

        self.client, self.server = socket.socketpair()
        self.addCleanup(self.client.close)
        self.addCleanup(self.server.close)

    def make_document(self, content=b"initial", token="/tmp/foo.txt"):
        doc = cotmate.RemoteDocument(
            connection=self.server,
            token=token,
            display_name=f"host:{token}",
            real_path=token,
            data=content,
            config=self.config,
            registry=self.registry,
        )
        self.addCleanup(doc.close, False)
        return doc


class TestRemoteDocumentLifecycle(DocumentTestCase):

    def test_writes_initial_content_to_mirror(self):
        doc = self.make_document(b"the content")

        self.assertTrue(doc.local_path.exists())
        self.assertEqual(doc.local_path.read_bytes(), b"the content")

    def test_mirror_path_preserves_remote_structure(self):
        doc = self.make_document(token="/home/user/notes.txt")

        self.assertEqual(doc.local_path.name, "notes.txt")
        self.assertEqual(doc.local_path.parent.name, "user")
        self.assertEqual(doc.local_path.parent.parent.name, "home")

    def test_mirror_is_under_mirrors_dir(self):
        doc = self.make_document()
        self.assertTrue(
            str(doc.local_path).startswith(str(self.config.mirrors_dir))
        )

    def test_changed_is_false_right_after_construction(self):
        doc = self.make_document()
        self.assertFalse(doc.changed())

    def test_changed_is_true_after_external_write(self):
        doc = self.make_document(b"initial")
        doc.local_path.write_bytes(b"changed! different size")
        self.assertTrue(doc.changed())

    def test_close_removes_mirror_file(self):
        doc = self.make_document()
        path = doc.local_path

        doc.close(notify_remote=False)

        self.assertFalse(path.exists())

    def test_close_deregisters_from_registry(self):
        doc = self.make_document()
        key = doc.registry_key

        self.registry.try_register(key, doc)
        doc.close(notify_remote=False)

        self.assertIsNone(self.registry.lookup(key))

    def test_close_is_idempotent(self):
        """Regression: calling close twice must not crash."""
        doc = self.make_document()
        doc.close(notify_remote=False)
        doc.close(notify_remote=False)  # must not raise


class TestSendSaveWireFormat(DocumentTestCase):

    def test_send_save_puts_body_before_terminating_blank_line(self):
        """Regression: the body must precede the trailing blank line.

        The bash rmate client reads `data: N` and then immediately
        reads N bytes.  Putting the blank line *before* the body
        corrupts the file on the remote end.
        """
        doc = self.make_document(b"initial")
        doc.local_path.write_bytes(b"updated!")
        doc.send_save()

        received = self.client.recv(4096)

        expected = (
            b"save\n"
            b"token: /tmp/foo.txt\n"
            b"data: 8\n"
            b"updated!"
            b"\n"
        )
        self.assertEqual(received, expected)

    def test_read_command_roundtrips_send_save(self):
        """What send_save writes, read_command must parse back."""
        doc = self.make_document(b"initial")
        doc.local_path.write_bytes(b"roundtrip")
        doc.send_save()

        command, headers, body = cotmate.read_command(self.client)

        self.assertEqual(command, "save")
        self.assertEqual(headers["token"], "/tmp/foo.txt")
        self.assertEqual(body, b"roundtrip")

    def test_send_save_handles_empty_file(self):
        doc = self.make_document(b"initial")
        doc.local_path.write_bytes(b"")
        doc.send_save()

        received = self.client.recv(4096)

        self.assertEqual(
            received,
            b"save\ntoken: /tmp/foo.txt\ndata: 0\n\n",
        )