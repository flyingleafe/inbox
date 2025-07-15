"""
Inbox AI - Smart folder watcher with desktop notifications.

A file system monitoring service that watches directories for changes
and sends desktop notifications. Designed for both interactive and
systemd service deployment.
"""

from .main import main

__version__ = "0.1.0"
__author__ = "Dmitrii Mukhutdinov"
__email__ = "flyingleafe@gmail.com"

__all__ = ["main"]
