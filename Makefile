.PHONY: help install install-dev test lint format clean build publish publish-test nix-build nix-test

# Default target
help:
	@echo "Available targets:"
	@echo "  install      - Install the package"
	@echo "  install-dev  - Install with development dependencies"
	@echo "  test         - Run tests"
	@echo "  lint         - Run linting checks"
	@echo "  format       - Format code"
	@echo "  clean        - Clean build artifacts"
	@echo "  build        - Build package"
	@echo "  publish      - Publish to PyPI"
	@echo "  publish-test - Publish to TestPyPI"
	@echo "  nix-build    - Build with Nix"
	@echo "  nix-test     - Test with Nix"

# Python package management
install:
	uv pip install .

install-dev:
	uv sync --extra dev

# Testing and code quality
test:
	pytest tests/ -v

lint:
	ruff check .
	mypy src/

format:
	ruff format .

# Build and publish
clean:
	rm -rf build/
	rm -rf dist/
	rm -rf src/*.egg-info/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -name "*.pyc" -delete

build: clean
	uv build

publish: build
	uv publish

publish-test: build
	uv publish --publish-url https://test.pypi.org/legacy/

# Nix targets
nix-build:
	nix build

nix-test:
	nix flake check

nix-dev:
	nix develop

# Combined targets
check: lint test
	@echo "All checks passed!"

all: clean format lint test build
	@echo "Package ready for release!"