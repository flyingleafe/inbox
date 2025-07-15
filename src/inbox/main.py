import argparse
import logging
import os
from pathlib import Path
import inotify.adapters as ia
from notifypy import Notify


def setup_logging(use_systemd: bool = False) -> None:
    """Set up logging with optional systemd support."""
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Remove existing handlers
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)
    
    if use_systemd:
        try:
            from systemd import journal
            handler = journal.JournalHandler()
            formatter = logging.Formatter('%(name)s[%(process)d]: %(levelname)s %(message)s')
        except ImportError:
            logging.warning("systemd-python not available, falling back to console logging")
            handler = logging.StreamHandler()
            formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    else:
        handler = logging.StreamHandler()
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    
    handler.setFormatter(formatter)
    logger.addHandler(handler)


def watch(args: argparse.Namespace) -> None:
    """Watch a directory for changes and send notifications."""
    logger = logging.getLogger(__name__)
    
    watch_path = Path(args.path).expanduser().resolve()
    if not watch_path.exists():
        logger.error(f"Watch path does not exist: {watch_path}")
        return
    
    if not watch_path.is_dir():
        logger.error(f"Watch path is not a directory: {watch_path}")
        return
    
    logger.info(f"Starting to watch directory: {watch_path}")
    
    i = ia.Inotify()
    i.add_watch(str(watch_path))

    try:
        for event in i.event_gen(yield_nones=False):
            if event is None:
                continue

            logger.debug(f"Raw event: {event}")
            _, type_names, path, filename = event
            
            if not filename:  # Skip directory events
                continue
                
            full_path = Path(path) / filename
            logger.info(f"File event: {full_path} - {type_names}")
            
            # Send notification
            if args.notify:
                try:
                    n = Notify()
                    n.title = "Inbox - File Event"
                    n.message = f"{filename}: {', '.join(type_names)}"
                    n.send()
                    logger.debug(f"Notification sent for {filename}")
                except Exception as e:
                    logger.error(f"Failed to send notification: {e}")
                    
    except KeyboardInterrupt:
        logger.info("Received interrupt signal, stopping...")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise
    finally:
        logger.info("Stopping directory watch")


def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Watch a directory for file changes and send notifications"
    )
    parser.add_argument(
        "--path", 
        type=str, 
        default=os.getenv("INBOX_WATCH_PATH", "~/Inbox"),
        help="Path to watch (default: ~/Inbox or INBOX_WATCH_PATH env var)"
    )
    parser.add_argument(
        "--notify",
        action="store_true",
        default=True,
        help="Send desktop notifications (default: True)"
    )
    parser.add_argument(
        "--no-notify",
        dest="notify",
        action="store_false",
        help="Disable desktop notifications"
    )
    parser.add_argument(
        "--systemd",
        action="store_true",
        help="Use systemd journal logging"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    # Set up logging
    setup_logging(use_systemd=args.systemd)
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    watch(args)


if __name__ == "__main__":
    main()
