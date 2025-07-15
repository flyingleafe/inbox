# Packaging Guide for Inbox AI

This document describes the complete packaging setup for the Inbox AI project, including PyPI publishing, Nix packaging, and systemd service integration.

## Overview

The project now includes full-featured packaging for multiple distribution channels:

- **PyPI package** via `uv` for Python package management
- **Nix package** with flake support for reproducible builds
- **NixOS service module** for system-wide deployment
- **Home Manager module** for user-level deployment
- **GitHub Actions CI/CD** for automated testing and publishing

## Package Structure

```
inbox/
├── .github/workflows/ci.yml    # GitHub Actions CI/CD
├── src/inbox/                  # Main package code
│   ├── __init__.py            # Package exports
│   ├── main.py                # Main application logic
│   ├── events.py              # Event handling (existing)
│   └── systemd_entry.py       # Systemd entry point
├── tests/                     # Test suite
│   ├── __init__.py
│   └── test_main.py
├── flake.nix                  # Nix flake configuration
├── pyproject.toml             # Python package configuration
├── Makefile                   # Build automation
├── README.md                  # User documentation
├── PACKAGING.md               # This file
├── LICENSE                    # MIT license
└── .gitignore                 # Git ignore rules
```

## Building and Publishing

### Python Package (PyPI)

```bash
# Install development dependencies
make install-dev

# Run all checks
make check

# Build package
make build

# Publish to TestPyPI (for testing)
make publish-test

# Publish to PyPI (for release)
make publish
```

### Nix Package

```bash
# Build with Nix
make nix-build

# Enter development shell
make nix-dev

# Test the flake
make nix-test
```

## Installation Methods

### 1. From PyPI

```bash
# Basic installation
uv add inbox-ai

# With systemd support
uv add "inbox-ai[systemd]"

# System-wide installation
pip install inbox-ai[systemd]
```

### 2. From Nix

```bash
# Direct installation
nix profile install github:flyingleafe/inbox-ai

# In a shell
nix shell github:flyingleafe/inbox-ai
```

### 3. NixOS System Service

Add to your `configuration.nix`:

```nix
{
  services.inbox-ai = {
    enable = true;
    watchPath = "/var/lib/inbox";  # Optional: custom watch path
    user = "inbox";                # Optional: custom user
    extraArgs = [ "--verbose" ];   # Optional: extra arguments
  };
}
```

This will:
- Create a dedicated `inbox` user (if using default)
- Set up a systemd service that starts automatically
- Create the watch directory with proper permissions
- Apply security hardening to the service

### 4. Home Manager User Service

Add to your `home.nix`:

```nix
{
  services.inbox-ai = {
    enable = true;
    watchPath = "~/Downloads";      # Optional: custom watch path
    notifications = true;           # Optional: enable notifications
    extraArgs = [ "--verbose" ];    # Optional: extra arguments
  };
}
```

This will:
- Install the package for the user
- Set up a user systemd service
- Enable desktop notifications (by default)
- Create the watch directory in the user's home

## Service Configuration

### Environment Variables

- `INBOX_WATCH_PATH`: Default directory to watch

### Command Line Options

- `--path PATH`: Directory to watch
- `--notify/--no-notify`: Enable/disable notifications
- `--systemd`: Use systemd journal logging
- `--verbose`: Enable verbose logging

### Systemd Integration

The package includes two entry points:

1. `inbox`: Regular command-line usage
2. `inbox-systemd`: Optimized for systemd (auto-enables journal logging)

## Security Features

The NixOS service includes comprehensive security hardening:

- Restricted file system access (only watch directory is writable)
- No privilege escalation
- Limited system calls
- Memory protection
- Namespace restrictions

## Development Workflow

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/flyingleafe/inbox-ai
cd inbox-ai

# Set up development environment
make install-dev

# Or use Nix
make nix-dev
```

### Running Tests

```bash
# Run Python tests
make test

# Run linting
make lint

# Run all checks
make check
```

### Code Formatting

```bash
# Format code
make format
```

### Building

```bash
# Clean and build everything
make all
```

## CI/CD Pipeline

The GitHub Actions workflow automatically:

1. **On Push/PR**: Runs tests, linting, and Nix builds
2. **On Main Branch**: Publishes to TestPyPI
3. **On Release**: Publishes to PyPI

Required GitHub secrets:
- `PYPI_API_TOKEN`: PyPI API token for publishing
- `TEST_PYPI_API_TOKEN`: TestPyPI API token for testing

## Release Process

1. Update version in `pyproject.toml`
2. Update version in `src/inbox/__init__.py`
3. Update version in `flake.nix`
4. Commit changes
5. Create a GitHub release/tag
6. CI will automatically publish to PyPI

## Troubleshooting

### Common Issues

1. **Import errors**: Ensure all dependencies are installed
2. **Permission errors**: Check directory permissions for watch path
3. **Notification issues**: Ensure desktop environment supports notifications
4. **Systemd issues**: Check service logs with `journalctl -u inbox-ai`

### Debugging

```bash
# Run with verbose logging
inbox --verbose --path /path/to/watch

# Check systemd logs
journalctl -u inbox-ai -f

# Test Nix build
nix build --verbose
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and add tests
4. Run `make check` to ensure quality
5. Submit a pull request

The CI pipeline will automatically test your changes across multiple Python versions and build systems.