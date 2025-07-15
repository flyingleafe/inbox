#!/usr/bin/env python3
"""
Systemd entry point for inbox-ai service.

This script automatically configures systemd journal logging
and starts the inbox service with appropriate settings.
"""

import os
import sys
import argparse
from pathlib import Path

from .main import main as inbox_main, setup_logging


def main() -> None:
    """Entry point for systemd service."""
    # Force systemd logging mode
    sys.argv.append("--systemd")
    
    # Default to no notifications in systemd mode (server/headless environments)
    if "--notify" not in sys.argv and "--no-notify" not in sys.argv:
        sys.argv.append("--no-notify")
    
    # Set default path from environment or systemd-friendly default
    if "--path" not in sys.argv:
        default_path = os.getenv("INBOX_WATCH_PATH", "/var/lib/inbox")
        sys.argv.extend(["--path", default_path])
    
    # Enable verbose logging in systemd mode
    if "--verbose" not in sys.argv and "-v" not in sys.argv:
        sys.argv.append("--verbose")
    
    # Call the main inbox function
    inbox_main()


if __name__ == "__main__":
    main()