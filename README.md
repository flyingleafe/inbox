# Inbox AI

A smart folder watcher that monitors file changes using inotify and sends desktop notifications. Perfect for monitoring download folders, document directories, or any location where you want to be notified of file activity.

## Features

- **Real-time monitoring**: Uses Linux inotify for efficient file system monitoring
- **Desktop notifications**: Optional desktop notifications for file events
- **Systemd integration**: Built-in support for running as a systemd service
- **Flexible configuration**: Environment variables and command-line options
- **Logging**: Comprehensive logging with systemd journal support
- **Nix packaging**: First-class Nix and NixOS support

## Installation

### From PyPI

```bash
# Install with uv (recommended)
uv add inbox-ai

# Or with pip
pip install inbox-ai

# For systemd integration
pip install inbox-ai[systemd]
```

### From Nix

```bash
# Install directly
nix profile install github:flyingleafe/inbox-ai

# Or add to your configuration.nix
environment.systemPackages = [ pkgs.inbox-ai ];
```

### NixOS Service

Add to your `configuration.nix`:

```nix
{
  services.inbox-ai = {
    enable = true;
    watchPath = "/home/user/Downloads";  # optional
    user = "user";                       # optional
  };
}
```

### Home Manager

Add to your `home.nix`:

```nix
{
  services.inbox-ai = {
    enable = true;
    watchPath = "~/Downloads";
    notifications = true;
  };
}
```

## Usage

### Command Line

```bash
# Monitor ~/Inbox (default)
inbox

# Monitor a specific directory
inbox --path /home/user/Downloads

# Disable notifications
inbox --no-notify

# Verbose logging
inbox --verbose

# Run with systemd logging
inbox --systemd
```

### Environment Variables

- `INBOX_WATCH_PATH`: Default directory to watch (default: `~/Inbox`)

### Configuration Options

```
--path PATH           Path to watch (default: ~/Inbox)
--notify              Send desktop notifications (default: True)
--no-notify           Disable desktop notifications
--systemd             Use systemd journal logging
--verbose, -v         Enable verbose logging
--help                Show help message
```

## systemd Service

For manual systemd setup (not needed with NixOS):

```ini
[Unit]
Description=Inbox AI File Watcher
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/inbox-systemd
Environment=INBOX_WATCH_PATH=/home/user/Inbox
User=user
Group=user
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

## Development

### Setup

```bash
# Clone the repository
git clone https://github.com/flyingleafe/inbox-ai
cd inbox-ai

# Install with uv
uv sync --extra dev

# Or with pip
pip install -e .[dev]
```

### Building and Publishing

```bash
# Build package
uv build

# Publish to PyPI
uv publish

# Run tests
pytest

# Lint and format
ruff check
ruff format
mypy src/
```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.