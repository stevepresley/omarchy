# Omarchy Advanced

> **Note**: This is a fork of [Omarchy](https://github.com/basecamp/omarchy) with advanced installation features. See [What's Different](#whats-different) below.

Turn a fresh Arch installation into a fully-configured, beautiful, and modern web development system based on Hyprland by running a single command. That's the one-line pitch for Omarchy (like it was for Omakub). No need to write bespoke configs for every essential tool just to get started or to be up on all the latest command-line tools. Omarchy is an opinionated take on what Linux can be at its best.

Read more about vanilla Omarchy at [omarchy.org](https://omarchy.org).

## What's Different

Omarchy Advanced adds **Advanced Mode** to the installer, offering:

- **Partition Selection** - Install to a specific partition instead of requiring a full disk
- **Installation Profiles** - Choose between Workstation or VM configurations
- **Optional Disk Encryption** - Enable or disable LUKS encryption based on your needs
- **Configurable Autologin** - Control whether the system auto-logs in or prompts for credentials
- **SSH Server Setup** - Optionally install and configure OpenSSH for remote access
- **VNC Remote Access** - Install wayvnc with Hyprland virtual display mirroring for headless operation

These features make Omarchy Advanced ideal for:
- **Virtual Machine deployments** - Unattended boot, SSH/VNC remote access
- **Development environments** - Flexible encryption and authentication options
- **Testing scenarios** - Partition selection for dual-boot or bare-metal testing

## Installation

### Standard Mode (Same as Vanilla Omarchy)

```bash
curl -sL https://omarchy.org | bash
```

### Advanced Mode (Coming Soon)

Advanced mode is available when using the custom ISO or running the installer manually. See [Installation Documentation](docs/installation.md) for details.

## Branches

This repository uses a multi-tier branching strategy:

- **`build`** (default) - Stable release branch with Omarchy Advanced features - **use this branch**
- **`main`** - Synced with upstream [basecamp/omarchy](https://github.com/basecamp/omarchy) (vanilla Omarchy)
- **`feature/*`** - Development branches

**For contributors**: Please read [CONTRIBUTING.md](CONTRIBUTING.md) to understand our workflow.

## License

Omarchy is released under the [MIT License](https://opensource.org/licenses/MIT).

