"""Tests for the main module."""

import logging
import tempfile
from unittest.mock import MagicMock, patch

import pytest

from inbox.main import setup_logging, watch


def test_setup_logging_console():
    """Test console logging setup."""
    setup_logging(use_systemd=False)

    logger = logging.getLogger()
    assert logger.level == logging.INFO
    assert len(logger.handlers) >= 1

    # Find the console handler
    console_handlers = [h for h in logger.handlers if isinstance(h, logging.StreamHandler)]
    assert len(console_handlers) >= 1


def test_setup_logging_systemd_mode():
    """Test systemd logging setup (will fall back to console if systemd not available)."""
    # This test just ensures systemd mode doesn't crash
    setup_logging(use_systemd=True)

    logger = logging.getLogger()
    assert logger.level == logging.INFO
    assert len(logger.handlers) >= 1


@patch('inbox.main.Notify')
@patch('inbox.main.ia.Inotify')
def test_watch_valid_directory(mock_inotify_class, mock_notify_class):
    """Test watching a valid directory."""
    # Create a temporary directory
    with tempfile.TemporaryDirectory() as tmpdir:
        # Mock inotify
        mock_inotify = MagicMock()
        mock_inotify_class.return_value = mock_inotify

        # Mock events
        events = [
            (None, ['IN_CREATE'], tmpdir, 'test_file.txt'),
            None  # End the generator
        ]
        mock_inotify.event_gen.return_value = iter(events)

        # Mock notification
        mock_notify = MagicMock()
        mock_notify_class.return_value = mock_notify

        # Create args mock
        args = MagicMock()
        args.path = tmpdir
        args.notify = True

        # Mock KeyboardInterrupt to stop the loop
        mock_inotify.event_gen.side_effect = KeyboardInterrupt

        # This should not raise an exception
        watch(args)

        # Verify inotify was set up correctly
        mock_inotify.add_watch.assert_called_once_with(tmpdir)


def test_watch_nonexistent_directory():
    """Test watching a non-existent directory."""
    args = MagicMock()
    args.path = "/this/path/does/not/exist"
    args.notify = True

    # Setup logging to capture the error
    setup_logging()

    with patch('inbox.main.logging.getLogger') as mock_get_logger:
        mock_logger = MagicMock()
        mock_get_logger.return_value = mock_logger

        watch(args)

        # Should log an error about non-existent path
        mock_logger.error.assert_called()
        error_call = mock_logger.error.call_args[0][0]
        assert "does not exist" in error_call


def test_watch_file_instead_of_directory():
    """Test error handling when path is a file instead of directory."""
    with tempfile.NamedTemporaryFile() as tmpfile:
        args = MagicMock()
        args.path = tmpfile.name
        args.notify = True

        setup_logging()

        with patch('inbox.main.logging.getLogger') as mock_get_logger:
            mock_logger = MagicMock()
            mock_get_logger.return_value = mock_logger

            watch(args)

            # Should log an error about path not being a directory
            mock_logger.error.assert_called()
            error_call = mock_logger.error.call_args[0][0]
            assert "not a directory" in error_call


@patch('inbox.main.Notify')
def test_watch_notification_disabled(mock_notify_class):
    """Test that notifications are not sent when disabled."""
    with tempfile.TemporaryDirectory() as tmpdir:
        with patch('inbox.main.ia.Inotify') as mock_inotify_class:
            mock_inotify = MagicMock()
            mock_inotify_class.return_value = mock_inotify

            # Mock a single event
            events = [
                (None, ['IN_CREATE'], tmpdir, 'test_file.txt'),
            ]
            mock_inotify.event_gen.return_value = iter(events)
            mock_inotify.event_gen.side_effect = KeyboardInterrupt

            args = MagicMock()
            args.path = tmpdir
            args.notify = False  # Disabled

            watch(args)

            # Notification should not be created
            mock_notify_class.assert_not_called()


if __name__ == "__main__":
    pytest.main([__file__])
