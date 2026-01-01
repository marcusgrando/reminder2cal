# Contributing to Reminder2Cal

Thank you for your interest in contributing to Reminder2Cal!

## How to Contribute

### Reporting Bugs

1. Check if the issue already exists in [GitHub Issues](https://github.com/marcusgrando/reminder2cal/issues)
2. If not, create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - macOS version and app version

### Suggesting Features

Open an issue with the `enhancement` label describing:
- The feature you'd like to see
- Why it would be useful
- Any implementation ideas you have

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run tests: `make test`
5. Run linting: `make lint`
6. Commit with clear messages
7. Push and open a Pull Request

### Code Style

- Follow Swift API Design Guidelines
- Run `make format` before committing
- Keep commits focused and atomic

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/reminder2cal.git
cd reminder2cal

# Build
make build

# Run tests
make test

# Run the app
make run
```

## Code of Conduct

Be respectful and constructive. We're all here to make great software.

## Questions?

Open an issue or start a discussion on GitHub.
