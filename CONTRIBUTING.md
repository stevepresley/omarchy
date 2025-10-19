# Contributing to Omarchy Advanced

Thank you for your interest in contributing to Omarchy Advanced! This guide will help you understand our workflow and how to contribute effectively.

## About This Project

Omarchy Advanced is a fork of [Omarchy](https://github.com/basecamp/omarchy) that adds advanced installation features including:

- Partition selection (not just full disk)
- Workstation vs VM installation profiles
- Optional disk encryption with LUKS
- Configurable autologin
- SSH server setup (openssh)
- VNC remote access (wayvnc with Hyprland virtual display mirroring)

## Branch Structure

This repository uses a three-tier branching strategy:

### Branch Roles

- **`build`** (default branch) - Our stable public release branch
  - Used for production ISO builds
  - Always in a releasable state
  - All features merge here via pull requests
  - **This is the branch you should use and contribute to**

- **`main`** - Synced with upstream `basecamp/omarchy`
  - Contains vanilla Omarchy releases
  - Periodically synced with upstream
  - Used to integrate upstream updates into `build`
  - **Do not create feature branches from this branch**

- **`feature/*`** - Development branches
  - Created from `build` branch
  - Merged back to `build` via pull requests
  - Deleted after merge

### Why This Structure?

- **Cleaner upstream merges**: `main` stays clean with only upstream code
- **Stable public branch**: `build` is always ready for release
- **Reduced conflicts**: Feature branches based on `build` include all custom code
- **Clear separation**: Upstream vs custom changes are clearly separated

## How to Contribute

### For New Contributors

1. **Fork the repository** on GitHub

2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/omarchy-advanced.git
   cd omarchy-advanced
   ```

3. **Add upstream remote** (to stay in sync):
   ```bash
   git remote add upstream https://github.com/stevepresley/omarchy-advanced.git
   ```

4. **Create a feature branch from `build`**:
   ```bash
   git checkout build
   git pull upstream build
   git checkout -b feature/your-feature-name
   ```

5. **Make your changes** and commit:
   ```bash
   git add .
   git commit -m "Description of your changes"
   ```

6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**:
   - Go to GitHub
   - Click "New Pull Request"
   - **Base repository**: `stevepresley/omarchy-advanced`
   - **Base branch**: `build`
   - **Head repository**: `YOUR-USERNAME/omarchy-advanced`
   - **Compare branch**: `feature/your-feature-name`

### For Maintainers

#### Syncing Upstream Changes

Periodically sync with upstream Omarchy:

```bash
# Update main with upstream changes
git checkout main
git pull upstream main
git push origin main

# Create PR to integrate into build
gh pr create --base build --head main \
  --title "Sync upstream Omarchy v3.x" \
  --body "Integrates latest changes from basecamp/omarchy"

# Review, test, and merge the PR
# Resolve any conflicts between upstream and custom features
```

#### Merging Feature Branches

```bash
# Feature branches should come via pull request
# Review the PR on GitHub
# Ensure CI/tests pass (if applicable)
# Merge via GitHub UI (creates merge commit)

# Or via command line:
git checkout build
git pull origin build
git merge --no-ff feature/feature-name
git push origin build
git branch -d feature/feature-name
```

## Branch Naming Conventions

Use descriptive names with appropriate prefixes:

- `feature/feature-name` - New features
- `fix/bug-description` - Bug fixes
- `docs/documentation-update` - Documentation changes
- `refactor/code-improvement` - Code refactoring
- `sync/upstream-v3.x` - Upstream sync PRs (main → build)

## Development Guidelines

### Code Style

Follow the existing code style in the repository:
- Use bash best practices for shell scripts
- Follow existing patterns in `install/` directory
- Use `run_logged` helper for installation steps
- Add comments for complex logic

### Testing

Since Omarchy Advanced is a system installer, testing requires:

1. **VM Testing**: Test in a fresh Arch VM before submitting
2. **Manual Testing**: Run through the installation flow completely
3. **Feature Testing**: Test both enabled and disabled states of features
4. **ISO Testing**: Build and test ISO if changes affect the installer

### Commit Messages

Write clear, descriptive commit messages:

```
Add VNC remote access configuration

- Install wayvnc package
- Create startup script for virtual display
- Configure Hyprland autostart
- Add firewall rule for port 5900

Closes #123
```

### Documentation

- Update relevant documentation when changing functionality
- Update [docs/plan.md](docs/plan.md) for significant changes
- Add comments to complex code sections
- Update README.md if user-facing features change

## Project Structure

Key directories and files:

```
omarchy-advanced/
├── bin/                    # Utility commands (omarchy-*)
├── config/                 # Application configurations
├── install/                # Installation stage scripts
│   ├── preflight/         # Pre-installation checks
│   ├── packaging/         # Package installation
│   ├── config/            # Configuration deployment
│   ├── login/             # Bootloader setup
│   └── post-install/      # Final cleanup
├── migrations/            # One-time upgrade scripts
├── themes/                # Visual themes
├── boot.sh                # Remote installation entry point
├── install.sh             # Main installer
├── CLAUDE.md              # AI assistant instructions
└── README.md              # Project overview
```

### Adding Installation Steps

1. Create script in appropriate `install/<stage>/` directory
2. Update `install/<stage>/all.sh` to source/run your script
3. Use `run_logged` helper for logging
4. Follow existing error handling patterns (`set -e`)

### Adding Utility Commands

1. Create executable script in `bin/` with `omarchy-*` prefix
2. Follow naming: `omarchy-cmd-*` (user commands) or `omarchy-dev-*` (dev tools)
3. Scripts automatically available in PATH after install

### Creating Migrations

Use `omarchy-dev-add-migration` to create timestamped migration scripts in `migrations/`. Migrations run once per system during preflight.

## Questions or Issues?

- **Bug reports**: Open an issue on GitHub
- **Feature requests**: Open an issue with detailed description
- **Questions**: Start a discussion on GitHub Discussions

## License

By contributing to Omarchy Advanced, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

**Thank you for contributing to Omarchy Advanced!**
