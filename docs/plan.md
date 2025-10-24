
## BRANCHING STRATEGY

This project uses a three-tier branching strategy to manage upstream updates and custom features:

### Branch Roles
- **main**: Synced with upstream `basecamp/omarchy` - vanilla Omarchy releases (currently v3.1)
- **build**: Our public stable branch - used for ISO builds and releases
- **feature/***: Development branches - created from `build`, merged back to `build` via PR

### Workflow
1. **Upstream Sync**: Periodically merge `upstream/main` → `main` to get latest Omarchy updates
2. **Integrate Upstream**: Create PR `main` → `build` to bring upstream changes into our stable branch
3. **Feature Development**:
   - Create feature branches FROM `build`: `git checkout -b feature/xyz build`
   - Develop and test changes
   - Create PR: `feature/xyz` → `build`
4. **ISO Builds**:
   - Production builds use `build` branch
   - Testing builds can use specific feature branches

### Why This Strategy?
- **Cleaner upstream merges**: `main` stays clean, only contains upstream code
- **Stable public branch**: `build` is always releasable
- **Reduced conflicts**: Feature branches based on `build` include all our custom code
- **Clear separation**: Upstream vs custom changes are clearly delineated

### Versioning
ISO builds are versioned with timestamp format: `omarchy-advanced-YYYYMMDD-HHMMSS-x86_64.iso`

Example: `omarchy-advanced-20251019-143022-x86_64.iso`

This allows:
- Multiple builds per day to be distinguished
- Easy chronological sorting
- Clear identification of build time

---

## ARCHITECTURAL PRINCIPLE: Default → Dotfiles Pattern

**CRITICAL PRINCIPLE**: All configurations MUST follow a strict Default → Dotfiles pattern. This applies to EVERY configuration in the project, not just new features.

### The Pattern

**Principle**: Separate defaults (immutable, part of Omarchy distribution) from user customization (mutable, in user's home directory).

**Implementation**:
1. **Defaults** live in: `~/.local/share/omarchy/default/[application]/`
   - Deployed during installation from repo's `default/` directory
   - Read-only (part of installed Omarchy package)
   - Contains baseline configuration that works for everyone
   - Updated by Omarchy upgrades/migrations

2. **User Overrides** live in: `~/.config/[application]/`
   - User can modify without affecting Omarchy defaults
   - Takes precedence over defaults
   - Preserved across Omarchy upgrades

3. **Application Loading Order**:
   - Application checks: `~/.config/[application]/config` first
   - If not found, falls back to: `~/.local/share/omarchy/default/[application]/config`
   - If neither exists, application uses its internal defaults

### Why This Pattern?

- **Non-destructive upgrades**: Users keep customizations when Omarchy updates
- **Easy rollback**: Users can delete `~/.config/X` to reset to defaults
- **Separation of concerns**: Omarchy manages defaults, users control overrides
- **Distribution consistency**: All users start from same defaults, then customize
- **Clear ownership**: Defaults = Omarchy, Overrides = User

### Applications Following This Pattern

**Currently Implemented**:
- ✅ Hyprland configs (default: `default/hypr/`, override: `~/.config/hypr/`)
- ✅ Waybar config (default: `default/waybar/`, override: `~/.config/waybar/`)
- ✅ Themes (default: `themes/`, override: `~/.config/omarchy/themes/`)
- ✅ Shell configs (.bashrc, .zshrc, etc.)

**Configurations Needing Audit** (packages WE ADDED ONLY):
- ⏳ wayvnc (new, must verify)
- ⏳ SSH/openssh
- ⏳ autologin configuration
- ⏳ greetd/regreet (greeter)

### Example: Correct Default → Dotfiles Implementation

**Incorrect (HARDCODED)** ❌:
```bash
# install/config/example.sh
cp /usr/share/example/default.conf /etc/example/config  # WRONG - hardcoded
```

**Correct (DEFAULT → DOTFILES)** ✅:
```bash
# install/config/example.sh
# Step 1: Deploy defaults during installation
mkdir -p ~/.local/share/omarchy/default/example/
cp example/default-config ~/.local/share/omarchy/default/example/config

# Step 2: Application sources this location
# ~/.config/example/config is checked first by the app
# If not found, app should fall back to ~/.local/share/omarchy/default/example/config
```

**Application Configuration** ✅:
```bash
# example-app startup logic (pseudocode)
if [[ -f ~/.config/example/config ]]; then
    source ~/.config/example/config  # User override
else
    source ~/.local/share/omarchy/default/example/config  # Omarchy default
fi
```

### When Adding New Features

1. **Never hardcode configuration paths** - always use Default → Dotfiles pattern
2. **Always create default files** in `default/[app]/` directory
3. **Always allow user override** in `~/.config/[app]/` directory
4. **Document the pattern** in scripts and code comments
5. **Test both paths**: verify default works AND verify user override works

---

**GOAL**
We are going to make our own version of omarchy to support some "advanced" features on the install. 

The default installer requires some opinionated "Defaults" and we would like to modify the installer to allow partition selection, and then several other options which will be configurable in a "VM setup" scenario. Those options are :

1. Enable disk encryption - The Advanced menu will follow the default install path with a few exceptions:
2. Enable SSH - Install and configure openssh to start by default 
3. Enabled wayvnc - Install and configure wayvnc to start by default, and to add a virtual display that mirrors the default display so that the VM can be connected to remotely.



**PLAN**
We will implement a few enhancements by adding an "Advanced mode" to the base installer menu.  The Advanced menu will follow the default install path with a few exceptions:

1. On the drive selection step, the user will be able to pick a particular partition to install omarchy to, instead of having to use an entire device(disk). 
2. Once the drive/partition is selected, add a step for the user to select "Workstation" or "VM" option. The "Workstation" option will continue the install wizard and present several additional options. The "VM" selection will still follow that menu, but set the defaults for these options to "Y" instead of "N" that will autoselect the following advanced options as true.
3. After this option is selected, a new item will be added to the install script for "Enable Disk Encryption". If "Workstation" is selected, the default will be "Y", if "VM", the default will be "N".  If the user selects "N", then SKIP the LUSK step to encrypt the disk.
4. If the disk encryption in NOT enabled in the prior step, add another step to ask if Autologin should be enabled or not. For Workstations, this should default to "Y", for VMs, this should default to "N".  If the user selects "N", change the autologin setting to N, so that the username/password is prompted when booting up the VM.
5. Add a new menu item to ask "Enable SSH" - In this step, Workstation defaults to "N" and VM defaults to "Y". If the user selects "Y", then install the openSSH package as follows:
```
sudo pacman -S openssh
sudo systemctl enable sshd
sudo systemctl start sshd
```
6. Add a new menu item to ask "Enable wayvnc". In this step, Workstation defaults to "N" and VM defaults to "Y". If the user selects "Y", then install the wayvnc package as follows:
```
sudo pacman -S wayvnc
```

Next, we need to add a startup script to '~/start-wayvnc.sh'
Create the file with the content as follows:
```
#!/bin/bash
# Wait for Virtual-1 to be ready
while ! hyprctl monitors | grep -q "Virtual-1"; do
    sleep 0.5
done

# Create and configure VNC display
hyprctl output create headless VNC-1
sleep 0.5
hyprctl keyword monitor "VNC-1,1920x1080@60,auto,1,mirror,Virtual-1"
wayvnc -o VNC-1 0.0.0.0 5900
```
Make it executable:
```
chmod +x ~/start-wayvnc.sh
```

We then need to update '~/.config/hypr/autostart.conf'. Add the following line on a new line at the end:
```
exec-once = ~/start-wayvnc.sh
```

7. At the end of the install process, if wayvnc was installed, get the ip address for the machine by running 
```
ip a | grep "inet "
```
and display the following and display to the user:
```
Once the VM reboots, it may be accessed via VNCViewer at vnc://{ip-address}:5900

If prompted, please ignore the encryption prompts in order to connect.
```

8. Once the install script runs manually, we will want to add openssh and wayvnc to the cache so are part of the distro so that they may run locally from the USB, and repackage the distro into ISO format.


## IMPLEMENTATION NOTES & CLARIFICATIONS

### Questions & Answers (from initial planning discussion)

**Q1: Partition Selection Scope**
- A: Partition selection will be investigated/implemented. Not currently in ISO version but available when running installer manually. This helps with bare-metal testing and dual-boot scenarios (though dual-boot support is not a primary goal unless "simple" to implement).

**Q2: Installation Context - Interactive Menu**
- A: Advanced mode will be an interactive menu option added to the installer script, available for both manual script runs AND ISO version installations. This should be presented at the beginning of the installation flow.

**Q3: LUKS Implementation**
- A: Need to research Arch Linux best practices for LUKS setup and determine where in the installation flow to configure (likely early in preflight or before packaging).

**Q4: Autologin Configuration**
- A: Need to locate existing autologin settings in the codebase to determine what needs to be modified (likely in display manager config or systemd service).

**Q5: wayvnc Autostart Location**
- A: Should verify `~/.config/hypr/autostart.conf` exists in `config/hypr/` directory structure and create if needed.

### Additional Implementation Requirements

1. **State Management** - Track user choices (Workstation vs VM, encryption enabled, SSH enabled, VNC enabled) throughout installation using environment variables or state file.

2. **Package Management** - `openssh` and `wayvnc` must be added to package lists so they're available on ISO when network connectivity is not available during installation.

3. **Firewall Configuration** - Add firewall rules for SSH (port 22) and VNC (port 5900) to first-run firewall setup.

4. **Script Organization** - Create new scripts following existing patterns:
   - `install/config/ssh.sh`
   - `install/config/wayvnc.sh`
   - Other scripts as needed for partition selection, LUKS, autologin config

5. **Testing** - Manual testing after each build to validate functionality.

6. **ISO Repackaging (Final Step)** - After validating scripting works via manual install, investigate if there's a GitHub Action or built-in repo scripts for ISO creation in the upstream omarchy repo.


## PROGRESS & ISSUES

### CRITICAL: Deploy Script Failure Documentation (2025-10-23 22:30 EDT - UNRESOLVED)

**Status**: ❌ BROKEN - Deploy script still non-functional

**What Happened**: Agent spent 50+ commits and excessive tokens iterating on `scripts/deploy-to-vm.sh` trying to create a one-command deployment script, repeatedly hitting the same SSH+sudo problem.

**Root Problem**: SSH commands that run scripts containing `sudo` commands MUST use the `-t` flag to allocate a pseudo-terminal. Without it, `sudo` fails with: "a terminal is required to read the password; either use ssh's -t option or configure an askpass helper"

**The Failing Pattern** (currently used):
```bash
ssh "$SSH_USER@$VM_IP" bash /tmp/deploy-wayvnc-monitor.sh
```

**The Correct Pattern** (NEEDS TO BE IMPLEMENTED):
```bash
ssh -t "$SSH_USER@$VM_IP" bash /tmp/deploy-wayvnc-monitor.sh
```

**Current File Status**:
- `scripts/deploy-to-vm.sh` - Line 39: **MISSING `-t` FLAG** - BROKEN
- `scripts/deploy-wayvnc-monitor.sh` - Created via wasteful iterations but valid
- Monitor scripts deployed but deployment script itself broken

**Immediate Fix Required for Next Agent**:
1. Open `scripts/deploy-to-vm.sh`
2. Go to line 39
3. Change: `ssh "$SSH_USER@$VM_IP" bash /tmp/deploy-wayvnc-monitor.sh`
4. To: `ssh -t "$SSH_USER@$VM_IP" bash /tmp/deploy-wayvnc-monitor.sh`
5. TEST IT: Run `./scripts/deploy-to-vm.sh 192.168.50.73` and verify no password prompts
6. Commit with message: "Fix deploy script SSH -t flag"

**Why This Happened**:
1. Agent kept iterating on the script without proper testing
2. Tried multiple "clever" solutions (sudo -S, ssh-agent, NOPASSWD) instead of adding the `-t` flag
3. Kept removing the `-t` flag when thinking SSH keys would bypass sudo requirements
4. Never actually tested the final script before declaring it "done"

**What Was Wasted**:
- 15+ git commits on deploy script alone
- ~120-150 documented tokens wasted in this session
- Estimated 400,000+ tokens in current session (16 MB conversation)
- Total project usage: ~1.25M tokens across 8 sessions
- Estimated 10-20% overall waste = 125,000-250,000 wasted tokens

**Files Affected**:
- `scripts/deploy-to-vm.sh` - **NEEDS FIX** - Missing `-t` flag on line 39
- `scripts/deploy-wayvnc-monitor.sh` - Valid but created through wasteful iterations
- `install/files/usr-local-bin-omarchy-wayvnc-monitor` - Valid monitor script
- `config/systemd/system/omarchy-wayvnc-monitor.service` - Valid service file

**Analysis Documents Created**:
- `docs/DEPLOY_SCRIPT_FAILURE_ANALYSIS.md` - Detailed 15+ commit breakdown
- `docs/COMPLETE_TOKEN_WASTE_ANALYSIS.md` - All 8 conversation files analyzed (51 MB total)

**Core Lesson**: SSH + sudo always requires `-t`. This is not negotiable. Test before committing.

---

### Session Log (2025-10-22 08:31 CDT)
- Reinforced behavioral directive by adding an explicit Priority Interrupt Rule to `claude.local.md` so feedback/questions are always acknowledged before resuming work; verified backup script succeeds after the edit per local procedures.

### Session Log (2025-10-20 17:12 CDT)
- Pre-check: attempted to run `scripts/backup-local.sh`; tar failed because archive step referenced `CLAUDE.local.md`, which does not exist on case-sensitive filesystems.
- Update: corrected script to package `claude.local.md` so the tarball can be created without error.
- Post-check: reran backup (with elevated permissions to write under `../__Backups/`) and confirmed archive creation plus cloud copy succeeded.
- Follow-up: regreet installer updates committed/pushed (`Switch greetd to regreet with dynamic wayvnc attach` and `Fix regreet package dependency for ISO build`).
- Build failure: ISO run stopped because pacman could not find package `regreet`; corrected scripts to depend on `greetd-regreet` (official Arch package name) in both installer and package manifest.

### Session Log (2025-10-20 18:32 EDT)
- Investigation: analyzed Hyprland binding files (`config/hypr/bindings.conf` and `default/hypr/bindings/*.conf`) and counted 47 bindings that rely on bare `SUPER` modifier, which are likely being intercepted by host OS/clients before they reach the VM.
- Next step: design VM-mode alternate keymap (candidate modifiers: `CTRL+ALT` or `SUPER+ALT`) and ensure no collisions with existing bindings or host shortcuts before wiring it into the advanced profile flow.

### Session Log (2025-10-20 18:45 EDT)
- Implementation: added `install/config/remap-keybindings.sh` and wired it into `install/config/all.sh` to rewrite Hyprland configs when `RemapKeys` is enabled in the advanced state file.
- Behavior: when flag is true, converts all bare `SUPER` bindings to `CTRL+ALT` and moves the screen-record shortcut from `CTRL+ALT+Print` to `SUPER+ALT+Print`; leaves workstation/default installs untouched.
- Follow-on: updated ISO configurator (`configs/airootfs/root/configurator` in omarchy-advanced-iso) to prompt for `RemapKeys`, use Workstation=N/VM=Y defaults, surface the choice in the summary table, and persist `remap_keybindings` into the advanced state JSON.
- Copy tweak: refreshed the profile selection blurb in the ISO configurator so Workstation mentions “keep Super keybindings” and VM highlights the CTRL+ALT remap.
- Bug fix (2025-10-21 08:05 EDT): expanded `install/config/remap-keybindings.sh` to rewrite both `~/.config/hypr` overrides and Omarchy’s default Hypr binding files so VM installs no longer fall back to Super-only shortcuts.
- Process adjustment (2025-10-21 09:04 EDT): added explicit directive in `claude.local.md` to stop immediately on mid-task user feedback, respond, and confirm next steps before resuming; requirement logged here to ensure behavior change is tracked.
- Investigation (2025-10-21 09:20 EDT): walker launcher in VM still shows stock theme; comparing `config/walker/config.toml` against upstream reveals missing settings (`additional_theme_location`, provider options). Plan to sync config and ensure service refresh.
- Fix (2025-10-21 09:42 EDT): Replaced local `config/walker/config.toml` with upstream configuration so walker 1.0 picks up Omarchy theme/assets during install; pushed update for next ISO build.
- Build stability (2025-10-21 09:55 EDT): Added `DisableDownloadTimeout` to ISO pacman configs and passed `--disable-download-timeout` to builder pacman commands to prevent mirror throttling timeouts during package sync.
- Session Log (2025-10-21 10:05 EDT)
- Kicked off deeper investigation into partition-selection feature (existing scripts: `bin/omarchy-drive-select`, `bin/omarchy-drive-info`); reviewing current drive-only picker to scope additions for partition awareness while ISO rebuild runs.
- Drafted `bin/omarchy-partition-select` to present disk + partition hierarchy using `lsblk` JSON output and gum choose; includes filesystem, mountpoint, and labels for clarity. Pending integration/testing on target system.
- Session Log (2025-10-21 10:22 EDT)
- wayvnc PAM integration: added fallback creation of `/etc/pam.d/wayvnc` in `install/config/wayvnc.sh` so systems missing the package-provided policy still include the standard `system-local-login` stack; ensures PAM auth works across installs.
- Session Log (2025-10-21 10:32 EDT)
- Enhancement: brand ISO boot splash with Omarchy Advanced logo (syslinux/systemd-boot assets).
- Greeter refresh: greetd Sway config now sets Omarchy background, installer drops `omarchy-advanced.desktop`, and hides upstream Hyprland/Sway sessions via overrides (pending verification on latest ISO; sway config command corrected to avoid login failure).
- Greeter verification steps (hotfix on current VM via SSH): update /etc/greetd/sway-config to use `output * bg`, add omarchy-advanced.desktop, hide upstream sessions, restart greetd.

### Investigation Findings

**Partition Selection:**
- Found `bin/omarchy-drive-select` - selects full drives using `lsblk` and `gum choose`
- Currently only selects drives (`/dev/sd*`, `/dev/nvme*`, etc.), not partitions
- Need to create `bin/omarchy-partition-select` to allow partition selection (e.g., `/dev/sda1`, `/dev/nvme0n1p2`)
- Can extend `omarchy-drive-info` to work with partitions as well

**Autologin Configuration:**
- Located in `install/login/plymouth.sh` (lines 97-126)
- Uses systemd service: `/etc/systemd/system/omarchy-seamless-login.service`
- Service runs `/usr/local/bin/seamless-login` which auto-starts Hyprland via UWSM
- To disable autologin: disable `omarchy-seamless-login.service` and enable `getty@tty1.service`

**LUKS/Encryption:**
- **CRITICAL DISCOVERY**: Omarchy ISO uses `archinstall` (Arch's official installer) to handle disk encryption BEFORE Omarchy install runs
- The Omarchy codebase (`install.sh`) assumes disk is already encrypted via archinstall
- Reference in `install/login/limine-snapper.sh` (line 3): mkinitcpio hooks include `encrypt`
- Current comment in `plymouth.sh:1` states: "rely on disk encryption + hyprlock for security"
- **Manual Installation Process**: Users run `archinstall` → select LUKS → set password → apply to partition → reboot → then run Omarchy installer
- **For Advanced Mode**: Need to integrate archinstall or implement custom LUKS setup to allow optional encryption during our installer flow
- Found `bin/omarchy-drive-set-password` which changes LUKS passwords on already-encrypted drives

**Hyprland Autostart:**
- Confirmed: `config/hypr/autostart.conf` exists and is deployed to `~/.config/hypr/autostart.conf`
- Currently minimal (just comments for extra autostart processes)
- Perfect place to add `exec-once = ~/start-wayvnc.sh`

**Firewall Setup:**
- Located in `install/first-run/firewall.sh`
- Already allows SSH (port 22/tcp) on line 10!
- Uses `ufw` (Uncomplicated Firewall)
- Need to add VNC port 5900/tcp when wayvnc is enabled

### Discovered Issues & Resolutions

**Issue 1: SSH is already allowed in firewall by default**
- Current: `install/first-run/firewall.sh` line 10 unconditionally allows SSH (port 22)
- Resolution: Keep as-is (SSH is generally useful), but conditionally add VNC port 5900 only when wayvnc is enabled

**Issue 2: LUKS encryption is handled by archinstall BEFORE Omarchy runs**
- Current: ISO configurator always enables LUKS in archinstall JSON
- Resolution: Modify ISO configurator to make LUKS optional based on Workstation/VM profile
- **CRITICAL**: Omarchy installer never touches LUKS setup - that's archinstall's job

**Issue 3: Partition selection doesn't exist**
- Current: ISO configurator only allows full disk selection
- Resolution: Add partition selection option in Advanced mode (enables dual-boot scenarios)

**Issue 4: Manual installation with existing LUKS**
- Current: No detection or warning when omarchy runs on LUKS-encrypted system
- Resolution: Add `install/preflight/luks-check.sh` to detect and warn users
- **OUT OF SCOPE**: Removing existing LUKS encryption (user must reinstall Arch without LUKS)

**Issue 5: Architecture clarification**
- Question: Do we modify ISO, omarchy installer, or both?
- **RESOLUTION**: Both repositories must be modified:
  - `omarchy-advanced-iso`: Handle disk/partition/LUKS decisions (before archinstall)
  - `omarchy-advanced`: Handle SSH/VNC/autologin configuration (after archinstall)
  - Clear separation of concerns: ISO handles disk setup, omarchy handles desktop config

**Issue 6: CRITICAL - Configurator execution flow is incorrect (2025-10-16)**
- **Discovered during ISO testing**: Advanced mode prompts never execute before archinstall runs
- **Root cause**: Summary/confirmation loop executes at wrong point in script flow
- **Current broken flow**:
  ```
  Line 30:  Installation Mode Selection ✅
  Line 48:  Keyboard Layout ✅
  Line 65:  User Account Setup ✅
  Line 124: ❌ SUMMARY SCREEN + CONFIRMATION ("Does this look right?")
            User confirms here and script proceeds
  Line 156: Disk Selection
  Line 216: ❌ Advanced Prompts (NEVER REACHED - user already confirmed!)
  Line 273+: Generate JSON and run archinstall
  ```
- **Why this breaks Advanced mode**:
  1. Summary shows empty/undefined advanced variables (displays as "Disabled")
  2. User confirms at line 148, breaking out of confirmation loop
  3. Advanced prompts at line 216 never execute because user already confirmed
  4. archinstall runs with default settings (LUKS enabled, SSH/VNC disabled)
  5. User never gets asked about encryption, SSH, VNC, or autologin
- **Required flow per plan.md lines 318-339**:
  ```
  Step 0: Installation Mode Selection
  Step 1: Keyboard Layout
  Step 2: User Account Setup
  Step 3: Disk Selection
  Step 4: (IF Advanced) Advanced Prompts (Profile, LUKS, SSH, VNC, Autologin)
  Step 5: Summary Screen with all values
  Step 6: User confirmation "Does this look right?"
  Step 7: Generate JSON and run archinstall
  ```
- **Resolution required**:
  1. Move disk selection (lines 156-214) to come BEFORE summary (insert after line 122)
  2. Keep advanced prompts after disk selection (lines 216-269)
  3. Move summary/confirmation loop (lines 124-154) to AFTER advanced prompts (after line 269)
  4. Ensure all variables are initialized before summary displays them
- **Files affected**: `omarchy-advanced-iso/configs/airootfs/root/configurator`
- **Status**: ✅ RESOLVED (commit 284a36a on 2025-10-16)
- **Resolution implemented**:
  - Moved disk selection to execute after user setup (before summary)
  - Moved summary/confirmation loop to execute AFTER advanced prompts
  - Updated summary to include disk selection
  - Enhanced "No, change it" logic to re-run all forms including advanced prompts
  - Verified no syntax errors with bash -n
- **New correct flow**:
  ```
  Line 30:  Installation Mode Selection ✅
  Line 48:  Keyboard Layout ✅
  Line 65:  User Account Setup ✅
  Line 124: Disk Selection ✅ (moved from line 156)
  Line 184: Advanced Prompts ✅ (if Advanced mode)
  Line 239: Summary + Confirmation ✅ (moved from line 124)
  Line 324: Generate JSON and run archinstall ✅
  ```

**Issue 7: ISO filename only includes date, not time (2025-10-16)**
- **Problem**: Multiple builds on same day produce same filename (e.g., `omarchy-2025.10.16-x86_64.iso`)
- **Impact**: Cannot distinguish between builds without checking filesystem timestamps
- **Root cause**: `configs/profiledef.sh` uses date format `%Y.%m.%d` for `iso_version`
- **Resolution**: Changed format to `%Y%m%d-%H%M%S` to include timestamp
- **Files affected**: `omarchy-advanced-iso/configs/profiledef.sh`
- **Status**: ✅ RESOLVED (commit 93b013a on 2025-10-16)
- **Result**: ISO filenames now include timestamp (e.g., `omarchy-20251016-181500-x86_64.iso`)

### Testing & Validation (2025-10-17)

**Build Performance Results:**
- Mac Mini (2025-10-16): 39m 40s (with cache)
- Windows LLM PC (WSL2, 2025-10-17): 13m 37s (FULL initial build - huge performance improvement!)

**Testing Checklist:**
1. ✅ Verify ISO boots successfully
2. ✅ Test VM profile installation - completed, identified issues below
3. ⏳ Test Standard mode:
   - Should use existing flow (no changes)
   - LUKS should be enabled by default
   - SSH/VNC/autologin not prompted
4. ⏳ Test Advanced mode - Workstation profile:
   - Verify all prompts appear in correct order
   - Profile selection appears
   - LUKS default: Yes
   - SSH default: No
   - VNC default: No
   - Autologin: Only prompt if LUKS=No
   - Verify summary shows all choices BEFORE confirmation
5. ✅ Post-installation verification (manual testing):
   - ✅ wayvnc works after reboot (tested on both VMs with encryption and without)
   - ⏳ Verify SSH is enabled/disabled per choice
   - ⏳ Verify autologin works per choice
   - ⏳ Check firewall rules (port 5900 if VNC enabled)
   - ⏳ Verify VNC info displays on completion screen

**Discovered Issues from Initial Testing (2025-10-17):**

**Issue 8: ISO rename logic fails for branch names with slashes**
- **Problem**: After successful build, script tries to rename ISO to include branch name but creates invalid path
- **Symptom**: `mv: cannot move 'omarchy-20251016-230319-x86_64.iso' to 'omarchy-20251016-230319-x86_64-feature/omarchy-advanced.iso': No such file or directory`
- **Root cause**: Branch name `feature/omarchy-advanced` contains slash, creating invalid directory structure
- **Impact**: Build succeeds but rename fails; ISO remains with timestamp-only name
- **Location**: `omarchy-advanced-iso/bin/omarchy-iso-make` line 72
- **Status**: ✅ RESOLVED (commit b950d50 on 2025-10-17)
- **Resolution**: Replace forward slashes in branch names with dashes using bash parameter expansion: `${OMARCHY_INSTALLER_REF//\//-}`

**Issue 9: Advanced Summary screen not displayed after installation**
- **Problem**: The IP address and VNC connection instructions were not shown after install completed
- **Expected behavior** (from plan.md lines 56-65):
  ```
  Once the VM reboots, it may be accessed via VNCViewer at vnc://{ip-address}:5900

  If prompted, please ignore the encryption prompts in order to connect.
  ```
- **Root cause**: VNC info was displayed in wayvnc.sh but immediately cleared by finished.sh
- **Impact**: User doesn't know how to connect to the VM via VNC
- **Status**: ✅ RESOLVED (commit e6fc0a9 on 2025-10-17)
- **Resolution**:
  - Store VNC IP in `/tmp/omarchy/vnc_ip.txt` during wayvnc setup
  - Display VNC info in finished.sh (after clear, before reboot prompt)
  - Properly gated: only displays if wayvnc was enabled in advanced mode

**Issue 10: Reboot button drops to command line instead of rebooting**
- **Problem**: Clicking the Reboot button after installation drops to command line, requiring manual `reboot` command
- **Expected behavior**: Clicking Reboot should immediately reboot the system
- **Root cause**: installer runs in chroot during ISO installation; reboot commands fail in chroot
- **Impact**: Poor user experience, confusing workflow
- **Status**: ✅ RESOLVED (commit e6fc0a9 on 2025-10-17)
- **Resolution**:
  - Create `/var/tmp/omarchy-install-completed` marker file for automated script to detect
  - Add error handling to reboot commands (`|| true`)
  - Exit gracefully if reboot fails (in chroot environment)
  - Automated script (outside chroot) handles actual reboot when marker exists

**Issue 11: wayvnc not running after installation completes**
- **Problem**: wayvnc service/process not running after install
- **Root cause**: Overcomplicated approach using VNC-1 headless output with mirroring; mirror syntax unreliable
- **Impact**: Cannot connect to VM via VNC as intended
- **Status**: ✅ RESOLVED (commit 692bd8b on 2025-10-17)
- **Resolution**:
  - **Simplified approach**: Stream the primary monitor (Virtual-1) directly with `wayvnc -o Virtual-1 0.0.0.0 5900`
  - Remove unnecessary VNC-1 headless output creation and mirror configuration
  - Dynamically detect primary monitor using `hyprctl monitors -j | jq -r '.[0].name'`
  - Wait for Hyprland to be ready with 30-second timeout
  - Add comprehensive logging to `~/.local/share/wayvnc.log`
  - Install `jq` for JSON parsing
- **Key insight**: No need for headless output or mirroring - wayvnc can stream the primary monitor directly
- **Testing**: After next install, wayvnc should start reliably on every boot

**Known Issues to Monitor:**
- Firmware warnings during build (cosmetic, expected)
- First build on new machine will be slower (package downloads)
- `gum: command not found` in omarchy-advanced-iso-make line 80 (cosmetic, from optional boot offer - gum is a TUI tool not installed on Mac)

**Issue 12: Repository renamed but documentation not updated (2025-10-19)**
- **Problem**: Repositories renamed to `omarchy-advanced` and `omarchy-advanced-iso` but git remotes and documentation still referenced old names
- **Status**: ✅ RESOLVED (commits in both repos on 2025-10-19)
- **Resolution**:
  - Updated git remote for omarchy-advanced: `origin` → `stevepresley/omarchy-advanced`
  - Updated git remote for omarchy-advanced-iso: `origin` → `stevepresley/omarchy-advanced-iso`
  - Updated all documentation (CLAUDE.md, CLAUDE.local.md, docs/plan.md) with new repo names
  - Created CONTRIBUTING.md for both repositories explaining branch strategy
  - Updated README.md for both repositories to identify as "Omarchy Advanced" fork
  - Set `build` as default branch on GitHub for both repos
  - Enabled branch protection on `main` and `build` branches

**Issue 13: Boot menus still said "Omarchy" instead of "Omarchy Advanced" (2025-10-19)**
- **Problem**: All boot menu entries (GRUB, SYSLINUX) showed "Omarchy" not "Omarchy Advanced"
- **Status**: ✅ RESOLVED (commit 7c67214 in omarchy-advanced-iso on 2025-10-19)
- **Resolution**:
  - Updated GRUB configs: `configs/grub/grub.cfg` and `configs/grub/loopback.cfg`
  - Updated SYSLINUX title: `configs/syslinux/archiso_head.cfg`
  - Updated SYSLINUX boot entries: `configs/syslinux/archiso_sys-linux.cfg` and `archiso_pxe-linux.cfg`
  - All boot menus now display "Omarchy Advanced" branding

**Issue 14: Standard/Advanced mode selection unnecessary (2025-10-19)**
- **Problem**: ISO showed "Standard/Advanced" mode prompt, but this is Omarchy Advanced ISO - everyone wants advanced features
- **Status**: ✅ RESOLVED (commit b3199dc in omarchy-advanced-iso on 2025-10-19)
- **Resolution**:
  - Removed Installation Mode selection entirely
  - Made Workstation/VM profile selection the FIRST prompt (Step 0)
  - Added detailed default information for each profile:
    - Workstation: Disk encryption (requires boot password), no SSH, no VNC, autologin
    - VM: No disk encryption, SSH, VNC, no autologin
    - Message: "All options can be changed, these are just the defaults to save you time!"
  - Removed all `INSTALLATION_MODE` gates - advanced options always show
  - Simplified summary to always display profile and advanced settings

**Issue 15: Autologin not disabling properly when set to "No" (2025-10-19)**
- **Problem**: Even when autologin was set to "No", system still auto-logged in as root after reboot
- **Root cause**: `autologin.sh` tried to disable `omarchy-seamless-login.service` BEFORE `plymouth.sh` created it
- **Status**: ✅ RESOLVED (commit 9c44297 in omarchy-advanced on 2025-10-19)
- **Resolution**:
  - Moved `autologin.sh` from `install/config/all.sh` to `install/login/all.sh`
  - Now runs AFTER `plymouth.sh` creates the autologin service
  - `systemctl disable omarchy-seamless-login.service` now works correctly

**Issue 15B: Autologin 'N' drops to root console and GUI doesn't launch (2025-10-20)**
- **Problem**: When autologin is set to "No", users are dropped into a root console login. Even after logging in, the GUI doesn't launch - stuck in console session.
- **Root cause investigation** (2025-10-19):
  - `autologin.sh` (runs at `install/login/all.sh:4`) correctly:
    - Disables `omarchy-seamless-login.service`
    - Enables `getty@tty1.service`
  - **BUT** `plymouth.sh` (runs at `install/login/all.sh:1`, BEFORE autologin.sh) always:
    - Enables `omarchy-seamless-login.service` (line 143-146)
    - Disables `getty@tty1.service` (line 149-151)
  - The seamless-login service is hardcoded to launch Hyprland for `$USER` without any login prompt
  - When autologin is disabled, we need:
    1. Getty to prompt for user login (not root)
    2. GUI to launch automatically after successful login
  - **The real problem**: plymouth.sh unconditionally configures autologin regardless of user settings
- **Status**: ✅ RESOLVED (2025-10-20)
- **Resolution implemented**:
  - Modified `install/login/plymouth.sh` (lines 143-162):
    - Now reads `enable_autologin` from `$OMARCHY_ADVANCED_STATE`
    - Only enables seamless-login and disables getty when autologin is enabled
    - When autologin is disabled, skips service configuration entirely
  - Modified `install/config/autologin.sh` (lines 22-31):
    - Creates `~/.bash_profile` when autologin is disabled
    - Auto-starts Hyprland on tty1 after manual login using `uwsm start -- hyprland.desktop`
    - Sources `~/.bashrc` for interactive shell configuration
  - This provides standard login prompt behavior with automatic GUI launch after login
- **Files changed**:
  - `install/login/plymouth.sh` - conditional service enable/disable
  - `install/config/autologin.sh` - added .bash_profile creation for GUI autostart

**Issue 16: Install script formatting issue (2025-10-19)**
- **Problem**: Profile description box in configurator not using proper formatting - box was left-aligned instead of centered with the logo
- **Root cause**: Line 35 in configurator used `--margin "1"` without `$PADDING_LEFT`
- **Status**: ✅ RESOLVED (2025-10-20)
- **Resolution implemented**:
  - Fixed configurator profile description box to use `--margin "1 0 1 $PADDING_LEFT"` for proper centering
  - Added "UI/Menu Formatting" section to CONTRIBUTING.md with:
    - Guidelines for using `$PADDING_LEFT` and `$PADDING_LEFT_SPACES`
    - Examples of properly formatted boxes and tables
    - Documentation of available helper functions
    - Explanation of why consistent formatting matters
- **Files changed**:
  - `omarchy-advanced-iso/configs/airootfs/root/configurator` - fixed profile box margin
  - `omarchy-advanced/CONTRIBUTING.md` - added formatting guidelines section

**Issue 17: System update pointing to old repo name (2025-10-20)**
- **Problem**: System update still pointing to https://github.com/stevepresley/omarchy NOT https://github.com/stevepresley/omarchy-advanced
- **Status**: ✅ RESOLVED (2025-10-22)
- **Resolution**: Updated all repository references in:
  - `boot.sh` - default repo now `stevepresley/omarchy-advanced`
  - `install/login/plymouth.sh` - seamless-login service documentation URL updated
  - `migrations/1754929475.sh` - migration script documentation URL updated
- **Commit**: `60cc894` "Update repository references from basecamp/omarchy to stevepresley/omarchy-advanced"

**Issue 18: keybinds not passing through (2025-10-20)**
- **Problem**: keybinds to omarchy-VMs are not passed through as they are captured by the client machine
- **Possible Solution**: Look through the keybinds in our repo and see if we were to change all SUPER-* keybinds to be SUPER-ALT, SUPER-CTRL or SUPER-Shift, if there are any conflicts. If we discover a set that does not have conflicting keybinds, offer the user to re-map the VM keybinds to that modifier.  In VM mode, default to YES, in Workstation mode, default to N.

**Issue 19: Regression - greetd/tuigreet boots to black screen (2025-10-21)**
- **Observation**: Latest VM image boots to blank (black) screen on both console and VNC; no login prompt is presented.
- **Suspected cause**: Commit 8098a31 swapped `regreet` for `greetd-tuigreet`. `tuigreet` is a text-mode greeter that does not render inside the Sway compositor, so greetd shows nothing while wayvnc streams the black scene.
- **Planned fix**: Restore graphical greeter by installing the correct Arch package (`regreet`) and updating `install/login/greetd.sh` to launch it under Sway (while re-attaching wayvnc for VNC access).
- **Status**: ✅ Fix implemented locally (2025-10-21); ✅ Pending verification on latest ISO build.

**Issue 19B: Greetd Sway Config Errors (2025-10-22)**
- **Problem 1**: Sway config error: "Unable to access background file '/usr/local/share/omarchy/branding/greeter-background.png' and no valid fallback provided"
  - **Root cause**: Script tried to use `default.png` which doesn't exist in tokyo-night theme
  - **Status**: ✅ RESOLVED (2025-10-22)
  - **Resolution**:
    - Changed background source to actual existing file: `1-scenery-pink-lakeside-sunset-lake-landscape-scenic-panorama-7680x3215-144.png`
    - Added fallback logic to find any available background
    - Updated sway config to use solid color (`#1a1b26`) if no background available
    - Prevents sway errors on boot
  - **Commit**: `d9d51bb` "Fix greetd sway config background file and error handling"

- **Problem 2**: Unwanted sessions appearing: "Hyprland (uwsm-managed)" option visible alongside "Omarchy Advanced"
  - **Root cause**: Hidden=true and NoDisplay=true not being respected by regreet, or sessions being recreated by package updates
  - **Status**: ✅ RESOLVED (2025-10-22)
  - **Resolution**:
    - Changed strategy from hiding to deletion: removed hyprland.desktop and sway.desktop files entirely
    - Only "Omarchy Advanced" session remains visible in greeter
    - Added systemd override that cleans up unwanted sessions on every boot (handles package reinstalls)
    - Ensures clean greeter experience even if packages get updated
  - **Commit**: `e2293f8` "Remove unwanted sessions from greetd greeter instead of hiding"

### Testing Greetd Changes on Running VMs (Before Full ISO Rebuild)

Two helper scripts available in `scripts/` for SSH-based testing:

**1. Test on a Running VM:**
```bash
cd /Volumes/Storage/Projects/omarchy-advanced
./scripts/test-greetd.sh 192.168.1.100
```

This script:
- Tests SSH connectivity to the VM
- Deploys updated greetd configuration
- Offers interactive testing options (SSH verify, VNC verify, or manual check)
- Validates that unwanted sessions were removed

**2. Manual Update (Advanced):**
```bash
./scripts/update-greetd-ssh.sh 192.168.1.100 [USER]
```

Direct update without interactive testing:
- `192.168.1.100` = VM IP address
- `USER` = SSH user (default: root)

**Testing Checklist After Update:**
- [ ] Login screen loads without sway config errors
- [ ] Only "Omarchy Advanced" session appears in greeter
- [ ] No "Hyprland (upstream)" or "Sway (upstream)" options visible
- [ ] Background image displays (or solid color fallback)
- [ ] VNC access to login screen works
- [ ] SSH access still works
- [ ] Can successfully login and launch Hyprland

**What the Scripts Deploy:**
1. Background image: `/usr/local/share/omarchy/branding/greeter-background.png`
2. Sway config: `/etc/greetd/sway-config` (with fallback background handling)
3. Omarchy session: `/usr/share/wayland-sessions/omarchy-advanced.desktop`
4. Systemd override: `/etc/systemd/system/greetd.service.d/remove-unwanted-sessions.conf`
5. Removes: `hyprland.desktop` and `sway.desktop`

**Issue 20: Pacman download stalls during ISO build (2025-10-21)**
- **Observation**: ISO build appeared to hang at `:: Proceed with download? [Y/n]` prompt
- **Root Cause**: AWS outage affecting package mirrors (external infrastructure issue, not code)
- **Status**: ✅ RESOLVED
- **Resolution**: Issue was infrastructure-related. Previous agent's attempted fixes (pacman timeout tweaks) broke the build and were reverted. No code changes needed.
- **Note**: Build hangs are environmental/mirror-related, not caused by our scripts

**Current Build Status (2025-10-19):**
- ✅ All commits pushed to remote
- ✅ Repository remotes updated to new names
- ✅ Branch protection enabled on `main` and `build` branches
- ✅ CONTRIBUTING.md and README.md created for both repos
- ✅ Boot menus rebranded to "Omarchy Advanced"
- ✅ Configurator simplified - Workstation/VM now first prompt
- ✅ Autologin bug fixed - properly disables when set to "No"
- ✅ Build script updated with automatic git pull
- ✅ Backup scripts synced with correct Google Drive paths

### Current Work In Progress (2025-10-19)

**Partition Selection Implementation**

Implementing partition selection to allow installing to specific partitions instead of full disks. This enables:
- Dual-boot scenarios (Windows + Omarchy, Mac + Omarchy)
- Testing on bare-metal without wiping entire disk
- Installation to specific NVMe partitions

**Design Decisions Made:**
- **Display Format**: Combined list showing disks and their partitions hierarchically
  ```
  /dev/sda (500GB SSD - Samsung)
    ├─ /dev/sda1 (500MB, vfat, /boot/efi) [EFI System]
    ├─ /dev/sda2 (100GB, ntfs, /mnt/windows) [Windows]
    └─ /dev/sda3 (350GB, unformatted)
  ```
- **Partition Info**: Show size, filesystem type, mount point (if mounted)
- **Boot Partition**: Install Limine bootloader to existing EFI partition, rely on auto-detection of other OSes
- **LUKS on Partition**: Allow encryption of single partition (boot remains unencrypted)
- **Warnings**: Multiple targeted warnings for different scenarios

**Warnings to Implement:**

1. **General Data Loss Warning** (existing, keep it):
   ```
   ⚠️ WARNING: Everything on the selected target will be PERMANENTLY ERASED.
   There is NO RECOVERY possible. Make sure you have backups!
   ```

2. **Partition + Dual Boot Warning** (new):
   ```
   ⚠️ DUAL-BOOT NOTICE:
   You selected a partition. Omarchy will install Limine bootloader which will
   attempt to auto-detect other operating systems (Windows, Mac, Linux).

   IF AUTO-DETECTION FAILS, manually edit /boot/limine.conf:

   For Windows:
     /Windows
     comment: Windows Boot Manager
     protocol: efi_chainload
     image_path: boot():/EFI/Microsoft/Boot/bootmgfw.efi

   For macOS:
     /macOS
     comment: macOS
     protocol: efi_chainload
     image_path: boot():/EFI/APPLE/APPLE.EFI

   See README.md for full dual-boot configuration guide.
   Advanced users only. Proceed with caution.
   ```

3. **VM + LUKS Warning** (new):
   ```
   ⚠️ HEADLESS VM WARNING:
   You have enabled disk encryption on a VM profile.

   With encryption enabled, you MUST physically enter the password at the
   console on EVERY boot. Remote access (SSH/VNC) will NOT work until
   someone enters the password.

   For unattended/headless VM operation, disable disk encryption.
   ```

4. **Partition + LUKS Warning** (new):
   ```
   ℹ️ PARTIAL ENCRYPTION NOTICE:
   You are encrypting only the selected partition (/dev/sdaX).
   Your boot partition will remain unencrypted.

   This provides less security than full-disk encryption but allows dual-boot.
   ```

**Greetd Regression Fix (2025-10-21)**
- Observed VM booting to black screen after switching greeter packages.
- Confirmed `greetd-tuigreet` cannot render inside Sway compositor, causing blank login screen locally and over VNC.
- Implemented fix to install `regreet` (official Arch package) instead, update `install/login/greetd.sh` to launch regreet and dynamically attach wayvnc using the compositor's `XDG_RUNTIME_DIR`/`WAYLAND_DISPLAY`.
- Updated package manifest and plan documentation to reflect `regreet` as the supported greeter.
- Pending verification: rebuild ISO / rerun installer to ensure regreet login renders correctly and VNC access still works.

**Dual-Boot OS Detection Research (2025-10-20):**

Investigated how Limine handles multi-boot scenarios:

**Automatic Detection:**
- Limine includes `limine-scan` utility (part of `limine-entry-tool` AUR package)
- Command: `sudo limine-scan` detects EFI boot entries and adds them to Limine config
- Works by scanning EFI System Partition for bootloaders (Windows, other Linux installs, macOS)
- Takes ~10 seconds to run and automatically adds entries to `/boot/limine.conf`

**Existing Omarchy Support:**
- `/etc/default/limine` already includes `FIND_BOOTLOADERS=yes` (see `install/login/limine-snapper.sh:41-42`)
- This setting may already enable automatic detection via limine-snapper-sync
- Need to verify if `limine-snapper-sync` uses this setting to run `limine-scan` automatically

**Manual Boot Entry Format:**
If automatic detection fails, manual entries can be added to `/boot/limine.conf`:
```
/Windows
comment: Windows Boot Manager
protocol: efi_chainload
image_path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
```

**Recommendation:**
- Test if current `FIND_BOOTLOADERS=yes` setting already handles dual-boot
- If not, add `limine-entry-tool` package to omarchy-other.packages
- Add post-install step to run `sudo limine-scan` after Limine installation
- This would provide automatic dual-boot detection with minimal additional code

**Implementation Tasks:**
- ⏳ Update `disk_form()` in configurator to detect and list partitions
- ⏳ Add partition information gathering (size, fstype, mount point)
- ⏳ Format partition list with indentation/hierarchy
- ⏳ Add all warning prompts at appropriate points
- ⏳ Update archinstall JSON generation to handle partition targets
- ⏳ Add dual-boot detection step (limine-scan) to post-install
- ⏳ Test with various scenarios (full disk, partition, dual-boot)

---

### wayvnc Authentication & Display Manager Redesign (2025-10-20)

**Current Problems:**
1. wayvnc runs without authentication - anyone can connect
2. wayvnc starts in user session (autostart.conf) - doesn't work if autologin disabled
3. autologin itself is problematic - users don't like it, security concern
4. autologin=N currently has bugs/errors during install
5. regreet greeter shows unnecessary session picker even when only one session exists

**Desired Behavior (RDP-like) - COMPLETE SCENARIO:**

**Initial Connection:**
1. VNC client connects to port 5900
2. User sees login screen with USERNAME and PASSWORD fields ONLY (no session picker)
3. User enters credentials and authenticates via PAM
4. After successful auth, wayvnc attaches to user's Hyprland session

**Multi-user Support & Reconnection:**
1. If user logs out or disconnects, greeter appears again
2. Different user can connect and log in (user switching)
3. If same user reconnects, they see login prompt again (fresh connection)
4. Each user gets their own Hyprland session with wayvnc attached

**Workstation vs VM Scenarios:**
- **VM (headless)**: Only remote access via VNC, wayvnc is the primary interface
- **Workstation (with monitor)**: User can log in locally at console AND remotely via VNC, wayvnc streams the session

**Why Session Picker is NOT needed:**
- Only one session available: "Omarchy Advanced"
- Session selection is unnecessary - auto-select the only available session
- Reduces login confusion and clicks for both local and remote access

**Desired Behavior (RDP-like):**
- wayvnc available at boot (before any user logs in)
- VNC clients see login screen with username/password only and authenticate with system credentials
- Works for both VM (headless) and Workstation (laptop remote access) scenarios
- No dedicated VNC user needed
- Supports multi-user login and reconnection without session picker

**Proposed Solution: greetd + wayvnc**

Replace the current autologin approach with greetd display manager:

**Architecture:**
1. **greetd** systemd service starts at boot
2. **Greeter compositor** (cage or sway) runs a graphical greeter (`regreet`)
3. **wayvnc with PAM** starts in greeter compositor config, streams login screen
4. **VNC users** connect remotely, see greeter, authenticate with system credentials
5. **After login** greetd switches to user's Hyprland session

**Configuration:**
- `/etc/greetd/config.toml` - greetd daemon config
- `/etc/greetd/sway-config` or `/etc/greetd/cage-config` - greeter compositor config that starts wayvnc
- `/etc/pam.d/wayvnc` - PAM config for wayvnc authentication
- `~/.config/wayvnc/config` - wayvnc config with `enable_pam=true`

**Packages Needed:**
- `greetd` - display manager daemon
- `regreet` - login greeter
- `cage` or `sway` - compositor for greeter
- `wayvnc` (already included, check if built with PAM support on Arch)

**Benefits:**
- ✅ Removes autologin entirely (cleaner, more secure)
- ✅ Standard login workflow everyone understands
- ✅ wayvnc works before login (VM headless access)
- ✅ PAM authentication with system users (no hardcoded passwords)
- ✅ Works for both Workstation and VM scenarios
- ✅ Fixes current autologin=N bugs

**Manual VNC Testing Checklist - CRITICAL (CANNOT be automated, requires human interaction)**

**NOTE**: These tests MUST be performed manually via RealVNC Viewer. I cannot programmatically test interactive login flows.

**Research Findings on regreet Configuration (2025-10-22):**

**regreet.toml Configuration Options:**
- Background image and fit style
- GTK theme selection
- Dark mode toggle
- Icon theme
- Cursor theme
- Cursor blink behavior
- Font selection
- Greeting message text
- Clock display settings
- Environment variables for sessions
- Reboot and shutdown commands
- X11 command prefix

**CSS Customization:**
- regreet supports custom CSS via `regreet.css` in greetd config directory
- Can use `--style` CLI argument to specify custom CSS location
- Full GTK4 CSS properties available for styling
- Demo mode available: `regreet --demo` to test CSS changes safely
- Can customize: colors, fonts, layout, spacing, widget styling, etc.
- Can style: edit icons, buttons, input fields, panels, etc.

**Session Picker Behavior:**
- regreet remembers last selected session per user
- **DEPRIORITIZED**: Cannot hide session picker when only one session exists (requires custom greeter)

**Available for Immediate Customization:**
- Omarchy theme branding via CSS
- Icon/cursor/font styling
- Background image and appearance
- Greeting message
- Unauthenticated button removal/styling (via CSS or config)

**Test 1: Initial Login with PAM Authentication** ⏳ IN PROGRESS - REQUIREMENTS FINALIZED (2025-10-23)

**GREETER REQUIREMENTS - Must Act Like RDP:**

1. **User field** - MUST be free text input (NOT combobox)
   - Reason: Combobox showing valid user accounts = SECURITY VULNERABILITY
   - Remove edit icon (not needed for text field)

2. **Session field** - MUST be completely hidden
   - Hide: Session label
   - Hide: Session combobox
   - Hide: Session edit button
   - Reason: Only one session (Omarchy Advanced) exists - selection unnecessary

3. **Unauthenticated buttons** - MUST be hidden or password-protected
   - Current Reboot/Power Off buttons accessible without login = SECURITY VULNERABILITY
   - Move behind authentication or remove entirely

4. **Branding/theming** - Apply Omarchy Advanced visual theme
   - Colors, fonts, background matching Omarchy branding

**DEPRIORITIZED (REQUIRES CUSTOM GREETER):**
- Session picker will still appear (regreet limitation - cannot be hidden via CSS/config)
- Full RDP-like behavior (no session picker) requires custom greeter implementation (future)

**Implementation Path:**
- Items 1-4 possible via regreet CSS customization and `regreet.toml` config
- Does NOT require custom greeter for current scope
- Can be done by modifying `/etc/greetd/regreet.css` and `regreet.toml`
- Session picker will appear but can be accepted with regreet remembering last selection
- **What user sees**:
  1. Non-branded white screen with unauthenticated Reboot/Power Off buttons (SECURITY ISSUE)
  2. "Welcome Back!" header
  3. User: combobox with 'steve' + edit icon for free text entry
  4. Session: combobox with 'Omarchy Advanced' + edit icon for free text entry
  5. Login button (blue)
  6. Password prompt only appears AFTER clicking Login button
- **Issues identified**:
  1. ❌ Unauthenticated Reboot/Power Off buttons accessible to anyone with VNC - **CRITICAL SECURITY**
  2. ❌ User selection combobox (should be direct username field)
  3. ❌ Session picker showing (unnecessary since only one session)
  4. ❌ No theming applied (white/generic, not Omarchy Advanced theme)
  5. ✅ Authentication works when Login clicked
  6. ✅ Hyprland launches successfully after auth
- **Key Finding**: Current greeter (regreet) does NOT meet desired scenario
- **CRITICAL ISSUES (MUST FIX)**:
  1. Unauthenticated Reboot/Power Off buttons - SECURITY VULNERABILITY
  2. No Omarchy theme branding - visual identity missing
- **DEPRIORITIZED (FUTURE)**:
  1. Session picker - will be removed with custom greeter implementation
- **PARTIALLY TESTED**: PAM authentication works with steve user - needs multi-user testing in Test 4

**Test 2: VNC Reconnection Behavior** ⏳ CRITICAL SECURITY IMPLEMENTATION REQUIRED

**SECURE SESSION MANAGEMENT REQUIREMENTS:**

**Requirement 1: Lock Screen on VNC Disconnect**
- Implement script triggered on wayvnc disconnect
- Script calls: `omarchy-lock-screen` or `loginctl lock-session`
- Lock screen immediately (don't wait for 5-min idle timeout)
- Purpose: Prevent unauthorized reconnection to unlocked session

**Requirement 2: Re-authentication on VNC Reconnect**
- Option A: Display greeter instead of running Hyprland session on reconnect
- Option B: On wayvnc disconnect → detach wayvnc from Hyprland so greeter displays again
- Either approach requires re-authentication before accessing session
- Purpose: Secure session isolation between VNC connections

**Current Behavior (INSECURE):**
- VNC disconnect → Session remains unlocked
- VNC reconnect → Anyone can access existing session without password
- Multiple connections can access same session simultaneously
- No re-authentication required on reconnection

**Test Results (confirming vulnerability):**
1. ✅ Disconnected VNC connection
2. ✅ Waited 2 seconds
3. ✅ Reconnected to VNC
4. ✅ Result: Got Hyprland desktop (no authentication required)
5. ✅ Got the running session (not login screen)

**Implementation Path:**
1. Create wayvnc disconnect hook script
2. Hook script triggers screen lock
3. Implement greeter fallback on wayvnc detach OR prevent simultaneous connections
4. Test: Disconnect → Lock → Reconnect → Greeter appears → Re-auth required
- **Expected**: Connection closes cleanly
- Reconnect to VNC: Connect to 192.168.50.73:5900 again
- **Expected**: See fresh login prompt (not re-connected to existing session)
- **If sees logged-in session**: wayvnc is maintaining session state incorrectly
- **Document**: What do you see? Login prompt or running session?

**Test 3: User Logout and Re-login** ⏳ CRITICAL ISSUE FOUND

**Test Steps:**
1. Press `SUPER+ESCAPE` to open Power menu
2. Select "Relaunch" (calls `uwsm stop`)
3. Check console and VNC display

**Test Results:**
- ✅ Console: greetd menu appears (correct)
- ❌ VNC: Grey screen (BROKEN - should show greeter login)

**CRITICAL FINDING:**
- wayvnc does NOT re-attach to greeter after user session ends
- When Hyprland session terminates, wayvnc stays detached
- VNC client sees grey screen instead of login prompt
- **ROOT CAUSE**: wayvnc needs mechanism to re-attach to greeter on session exit
- **RELATED TO TEST 2**: This is part of secure session management
- User logs out → should see greeter again (via VNC) → forces re-auth on next login

**What's needed:**
- Hook on user session exit that triggers wayvnc re-attach to greeter
- OR: wayvnc should auto-detect greeter availability and re-attach

**Test 4: User Switching** ⏳
- Prerequisites: User steve logged in
- Open RealVNC: Disconnect while user steve is logged in
- **Expected**: Greeter appears (user steve's session paused)
- Try to login as different user (create test user first if needed)
- **Expected**: See login prompt, can authenticate as different user
- **Expected**: New user gets their own Hyprland session (not steve's)
- **Document**: Can you login as different user? Is it a separate session?

**Test 4: Session Re-attachment After Login** ⏳ COMPLETED - ISSUES FOUND

**Test Steps:**
1. Log in via console greeter (wayvnc stuck on grey)
2. Wait for Hyprland to launch
3. Observe transition and UX

**Test Results:**
1. ✅ Logged in via console
2. ✅ After desktop launches, Hyprland session available on both console and VNC
3. ❌ Confusing UX: Tokyo-night wallpaper hardcoded (same as greeter) - should ask user preference
4. ❌ Black screen visible during transition with terminal commands showing on console
5. ❌ No loading dialog/splash screen to hide boot sequence

**ISSUES IDENTIFIED:**

**Issue 1: Hardcoded Greeter Wallpaper - FIX REQUIRES DEFAULT→DOTFILES PATTERN**
- PROBLEM: Tokyo-night wallpaper hardcoded in `/etc/greetd/sway-config`
- CORRECT PATTERN (Default→User Override):
  1. Store DEFAULT greeter config in: `~/.local/share/omarchy/default/greetd/sway-config`
  2. Use DEFAULT Omarchy Advanced wallpaper (TBD - needs user input)
  3. Allow user override in: `~/.config/greetd/sway-config`
  4. greetd reads from user override first, falls back to default if not present
- PATTERN APPLIES TO: All greetd configs, not just wallpaper
- **ACTION REQUIRED**: Determine default Omarchy Advanced greeter wallpaper
- **PRINCIPLE**: STOP HARDCODING - implement Default→Dotfiles pattern for ALL configurations

**VERIFICATION STATUS (2025-10-23)**: As part of implementing Default→Dotfiles pattern project-wide, ALL four packages we added MUST follow this pattern:

**Verification Results**:

**1. wayvnc** ❌ DOES NOT FOLLOW PATTERN
- Location: `install/config/wayvnc.sh` lines 36-49
- Issue: Config hardcoded with `sudo tee /etc/wayvnc/config`
- No defaults in `default/wayvnc/` directory
- No user override capability in `~/.config/wayvnc/config`
- Service template also hardcoded (lines 53-72)
- **FIX REQUIRED**: Move to Default→Dotfiles pattern

**2. SSH/openssh** ✅ FOLLOWS PATTERN (by default)
- Location: `install/config/ssh.sh`
- Finding: SSH installation only installs package and enables service, uses system defaults
- No custom configs deployed, relies on `/etc/ssh/sshd_config` (system-wide, not user-level)
- No issue - this is appropriate for system services
- SSH is system-level; user-level configs would be unusual

**3. autologin configuration** ❌ DOES NOT FOLLOW PATTERN
- Location: `install/login/plymouth.sh` (seamless-login service - now deprecated)
- Issue: Seamless login service hardcoded (lines 97-126)
- Helper script compiled and placed directly in `/usr/local/bin/seamless-login`
- Service unit file created directly with hardcoded template
- Note: Service is deprecated (line 143-146 says greetd replaced it)
- No defaults stored in `default/` directory
- **FIX REQUIRED**: If keeping seamless-login, move to Default→Dotfiles pattern

**4. greetd/regreet** ❌ DOES NOT FOLLOW PATTERN
- Location: `install/login/greetd.sh`
- Issues:
  * Sway config hardcoded directly (lines 45-58)
  * Wallpaper hardcoded (line 50: `bg "#1a1b26" solid_color`)
  * wayvnc attach script hardcoded (lines 25-39)
  * Greeter session files created directly (lines 73-106)
  * Systemd overrides hardcoded (lines 111-131)
- No defaults in `default/greetd/` directory
- No user override capability in `~/.config/greetd/`
- Already documented in Issue 1
- **FIX REQUIRED**: Move to Default→Dotfiles pattern

---

### Issues Requiring Implementation

**Issue 21: wayvnc Does Not Follow Default→Dotfiles Pattern (2025-10-23)**
- **Problem**: wayvnc configuration is hardcoded in `install/config/wayvnc.sh`
- **Current behavior**:
  - Line 36-49: wayvnc config written directly with `sudo tee /etc/wayvnc/config`
  - Line 53-72: systemd service template created directly with `sudo tee /etc/systemd/system/wayvnc.service`
  - No default files in repository
  - Users cannot customize wayvnc config without modifying installation scripts
- **Required fix**:
  1. Create `default/wayvnc/config` with default wayvnc configuration
  2. Create `default/wayvnc/wayvnc.service` with default systemd service
  3. Update `install/config/wayvnc.sh` to:
     - Deploy defaults to `~/.local/share/omarchy/default/wayvnc/`
     - Check if user override exists in `~/.config/wayvnc/config` first
     - Use user override if present, otherwise use defaults
  4. Document the override mechanism
- **Status**: ⏳ PENDING IMPLEMENTATION

**Issue 22: autologin (seamless-login) Does Not Follow Default→Dotfiles Pattern (2025-10-23)**
- **Problem**: Seamless login service is hardcoded in `install/login/plymouth.sh`
- **Current behavior**:
  - Line 18-95: Helper script code compiled directly
  - Line 97-126: Service unit file created directly with `sudo tee`
  - No default files in repository
  - Service is deprecated (greetd replaced it per line 143-146)
- **Required fix** (if keeping seamless-login):
  1. Create `default/plymouth/seamless-login.c` with helper source
  2. Create `default/plymouth/omarchy-seamless-login.service` with default service
  3. Update `install/login/plymouth.sh` to:
     - Deploy defaults to `~/.local/share/omarchy/default/plymouth/`
     - Compile from default location
     - Use default service file template
  4. Consider: Should seamless-login be removed entirely since greetd replaced it?
- **Status**: ⏳ PENDING IMPLEMENTATION

**Issue 23: greetd/regreet Does Not Follow Default→Dotfiles Pattern (2025-10-23)**
- **Problem**: All greetd configuration is hardcoded in `install/login/greetd.sh`
- **Current behavior**:
  - Line 14-21: greetd config.toml created directly
  - Line 25-39: wayvnc attach script created directly
  - Line 45-58: Sway config created directly with hardcoded wallpaper
  - Line 73-106: Session desktop files created directly
  - Line 111-131: Systemd overrides created directly
  - No default files in repository except greeter background image
  - Users cannot customize greeter without modifying installation scripts
- **Required fix**:
  1. Create `default/greetd/` directory with:
     - `config.toml` - default greetd configuration
     - `sway-config` - default Sway compositor config with DEFAULT wallpaper (TBD)
     - `greetd-wayvnc-attach` - default wayvnc attach script
     - `omarchy-advanced.desktop` - default session file
  2. Update `install/login/greetd.sh` to:
     - Deploy defaults to `~/.local/share/omarchy/default/greetd/`
     - Check if user override exists in `~/.config/greetd/` first
     - Use user override if present, otherwise use defaults
  3. Ensure greetd startup loads from user override first, falls back to defaults
  4. Document override mechanism
  5. **ACTION REQUIRED**: Determine DEFAULT Omarchy Advanced greeter wallpaper (blocking)
- **Status**: ⏳ PENDING IMPLEMENTATION (blocked on greeter wallpaper decision)

**Issue 24: VNC Reconnection Security - No Screen Lock on Disconnect (2025-10-23)**
- **Problem**: When user disconnects VNC, session remains unlocked and accessible
- **Current behavior** (Test 2 findings):
  1. User logs in via VNC and gets Hyprland session
  2. User disconnects VNC
  3. Reconnects to VNC
  4. Gets immediate access to unlocked session (no re-authentication)
  5. Multiple connections can access same session simultaneously
- **Security vulnerability**: Anyone with network access can reconnect and use existing session
- **Implementation Status**: ✅ REFACTORED (2025-10-23)
- **Root cause identified and FIXED**:
  - wayvnc runs as root, socket at `/tmp/wayvncctl-0` owned by root
  - Original implementation: Monitor ran as user → Permission denied accessing socket
  - **SOLUTION**: Changed to system service running as root → Can access socket
- **Refactoring completed**:
  1. ✅ Created system service: `config/systemd/system/omarchy-wayvnc-monitor.service`
     - Runs as root (`User=root`)
     - Targets `multi-user.target` instead of graphical session
     - No graphical session dependencies
  2. ✅ Updated monitor script: `bin/omarchy-wayvnc-disconnect-lock`
     - Added context detection: if EUID==0 (root), skip loginctl lock
     - Detach still works as root and is sufficient to force greeter
  3. ✅ Updated install script: `install/config/wayvnc.sh` (lines 95-104)
     - Now deploys system service to `/etc/systemd/system/`
     - Uses `sudo systemctl` to enable instead of `systemctl --user`
  4. ✅ Updated deploy script: `scripts/deploy-to-vm.sh` (lines 43-54)
     - Deploys system service file via SCP
     - Enables with `sudo systemctl enable --now`
     - Updated test instructions for system service
- **Testing Results** (2025-10-23):
  - ✅ Monitor service successfully detects VNC client disconnect events
  - ✅ Monitor correctly calls `wayvncctl detach` on disconnect
  - ✅ wayvnc correctly detaches (client sees grey screen)
  - ❌ BUT: Grey screen persists on reconnect (greeter not re-attaching)
  - Root cause: Issue 26 problem - greeter not re-attaching wayvnc
- **Status**: ✅ PARTIALLY WORKING - Detach works, but greeter re-attach missing (Issue 26)

**Issue 25: VNC Reconnection UX - No Greeter on Reconnect (2025-10-23)**
- **Problem**: When user disconnects and reconnects VNC, they should see login prompt again
- **Current behavior** (Test 2 findings):
  - Disconnect VNC → Session remains open
  - Reconnect to VNC → Get existing session without re-authentication
  - Expected: Reconnect to VNC → See greeter login prompt (force re-auth)
- **Implementation Status**: ⏳ READY TO TEST (2025-10-23)
  - Issue 24 refactoring now complete
  - Implementation should work: `wayvncctl detach` called on disconnect
  - Ready to test on VM
- **How it should work**:
  1. VNC client disconnects → event monitor detects disconnect
  2. Monitor detaches wayvnc (`wayvncctl detach`) so VNC shows grey screen
  3. User reconnects to VNC → sees grey screen (wayvnc is detached)
  4. Greeter is still running on console
  5. Greeter Sway config attaches wayvnc → VNC users can now see greeter login prompt
  6. User must re-authenticate (secure session isolation)
- **Status**: ⏳ READY TO TEST

**Issue 26: wayvnc Does Not Re-attach to Greeter (VNC Disconnect & Session Exit) (2025-10-23)**
- **Problem**: When wayvnc is detached (either via Issue 24 disconnect OR session exit), greeter does NOT re-attach on VNC reconnect
- **Current behavior** (Testing 2025-10-23):
  - Scenario 1 (VNC disconnect): User in Hyprland → Disconnect VNC → Reconnect → Grey screen (greeter NOT visible)
  - Scenario 2 (Session exit): User in Hyprland → SUPER+ESC Relaunch → Console shows greeter → VNC shows grey screen
  - Expected: Both scenarios should show greeter login prompt on VNC
- **Root cause**: Greeter's Sway config is NOT attaching wayvnc when greeter starts
  - Greeter config may not exist, may not be executable, or may not be running
  - Need to verify greeter Sway config has wayvnc attach command
- **Implementation status**: ❌ NOT WORKING
  - `bin/omarchy-wayvnc-reattach-greeter` script exists but NOT being called
  - Greeter's wayvnc attach command NOT triggering on reconnect
  - Need to verify/fix greeter startup hooks
- **Blocking**: Issue 24 cannot be considered complete until Issue 26 is fixed
  - Detaching wayvnc only solves half the problem
  - Reconnect must show greeter, not grey screen
- **Status**: ❌ BROKEN - Greeter attachment missing

**Issue 27: Login Sequence Visibility - Black Screen During Transition (2025-10-23)**
- **Problem**: During greetd→Hyprland transition, user sees black screen with visible terminal output
- **Current behavior** (Test 4 findings):
  1. User enters credentials in greeter
  2. After authentication, black screen appears
  3. Terminal commands visible on console during Hyprland startup
  4. Hyprland eventually launches
  5. Poor UX - looks like system is broken
- **Note**: This is LOGIN sequence issue, NOT boot sequence
- **Implementation** (2025-10-23):
  - Created `bin/omarchy-show-splash` - displays splash screen during Hyprland startup
  - Script uses `swaybg` to show loading image or solid color
  - Modified `install/login/greetd.sh` to setup splash directory structure
- **How it works**:
  1. After user authentication, `omarchy-show-splash` is called
  2. Script displays loading image from `~/.local/share/omarchy/default/greetd/splash.png`
  3. Falls back to solid color if image not found
  4. Waits for Hyprland to become available (checks for socket)
  5. When Hyprland ready, exits and launches Hyprland
  6. Provides visual feedback instead of black screen
- **User customization**:
  - Users can place custom splash.png in `~/.config/omarchy/splash.png`
  - Script checks user location first, falls back to default
- **Integration**:
  - Need to wire into greetd/regreet autostart or Hyprland session startup
  - Currently created but not yet integrated into startup flow
- **Status**: ⏳ PARTIALLY IMPLEMENTED (script created, needs integration with greetd session startup)

**Issue 3: wayvnc Reconnection (from Test 3)**
- wayvnc still stuck on grey screen after logout
- Need to implement wayvnc re-attach to greeter on session exit

**Test 6: Headless VM Scenario** ⏳
- Prerequisites: VM has no monitor/console connected
- Only access is via VNC
- **Steps**:
  1. Boot VM
  2. Wait for greetd to start
  3. Connect via VNC
  4. Log in and get Hyprland session
- **Expected**: Complete workflow with only VNC access
- **Document**: Does entire flow work with only VNC? Any missing components?

**Known Issues to Investigate:**
- Session picker appearing in regreet (unnecessary with single Omarchy Advanced session)
- wayvnc detached mode behavior across user/session boundaries
- PAM authentication state management in wayvnc
- Greeter → User session transition reliability

**Implementation Tasks (POST-VERIFICATION):**
- Custom Omarchy greeter only if wayvnc PAM doesn't fully support the scenario
- Otherwise: Configure regreet to hide unnecessary session picker
- Remove seamless-login service and autologin.sh (if not already done)
- Update configurator to remove autologin prompt (if not already done)

**Research Findings (2025-10-20):**

✅ **PAM Support in Arch wayvnc:**
- Arch wayvnc package HAS PAM support compiled in
- PAM listed as both make dependency (compile-time) and optional dependency (runtime)
- August 2024 commit confirms PAM config installation
- `/etc/pam.d/wayvnc` should be installed by package

✅ **Greeter Compositor: Must Use Sway**
- Cage does NOT work with wayvnc - exits with "Virtual Pointer protocol not supported"
- Sway is REQUIRED for wayvnc support (has wlr-layer-shell-unstable)
- Sway also provides better multi-monitor support
- Configuration: Create dedicated `/etc/greetd/sway-config` that starts greeter + wayvnc

✅ **wayvnc Session Transition: Detached Mode**
- wayvnc supports detached mode (`-D` flag) - runs without compositor
- `wayvncctl attach` dynamically attaches to running compositor
- Example scripts: `auto-attach.py` automatically attaches to any running compositor
- Single wayvnc instance persists across greeter → user session transition!

**Architecture (Confirmed):**
```
1. wayvnc.service (systemd) - starts wayvnc in detached mode at boot
2. Greeter Sway config - wayvncctl attach to greeter compositor
3. User Hyprland autostart - wayvncctl attach to user session
4. PAM handles authentication - users authenticate with system credentials
```

**Configuration Files Needed:**
```
/etc/systemd/system/wayvnc.service - systemd service running wayvnc -D
/etc/greetd/config.toml - greetd daemon config
/etc/greetd/sway-config - Sway compositor for greeter, runs regreet + wayvncctl attach
/etc/wayvnc/config - wayvnc config with enable_pam=true
/etc/pam.d/wayvnc - PAM authentication config (installed by package)
~/.config/hypr/autostart.conf - user session runs wayvncctl attach
```

**Example greetd config.toml:**
```toml
[terminal]
vt = 1

[default_session]
command = "sway --config /etc/greetd/sway-config"
user = "greeter"
```

**Example /etc/greetd/sway-config:**
```
exec /usr/local/bin/greetd-wayvnc-attach
exec regreet
```

**Example /etc/wayvnc/config:**
```
address=0.0.0.0
port=5900
enable_pam=true
```

### Outstanding Tasks (Logo Updates)
- ✅ Update ASCII art logo files (logo.txt and icon.txt) with "advanced" branding
- ✅ Update PNG logo files (icon.png, default/plymouth/logo.png)
- ✅ Update SVG logo file (logo.svg)

### Pre-Merge Verification Checklist (2025-10-22)

Before merging `feature/omarchy-advanced` to `build`, the following MUST be verified:

**Critical Blockers - Must Be Verified:**

1. ✅ **Issue 19B Fixes** (Greetd Sway Config - RESOLVED 2025-10-22):
   - Commits: d9d51bb, 6cc536c, e2293f8, ac41de0, 19e133b
   - Fix: Corrected background file path and session filtering
   - Verification needed: Latest ISO build must include these commits and show working greeter

2. ✅ **Issue 19 Fix** (greetd/regreet - RESOLVED 2025-10-21):
   - Fix: Switched to regreet (graphical) instead of tuigreet (text-based)
   - Verification needed: Latest ISO must boot to login prompt (not black screen)

3. ✅ **Keybind Remapping** (Issue 18 - IMPLEMENTED):
   - Script: `install/config/remap-keybindings.sh`
   - Behavior: Converts bare SUPER to CTRL+ALT for VM installations
   - Verification needed: Test on actual VM installation to confirm remapping works

4. ⚠️ **Issue 20** (Pacman Build Stability - UNKNOWN):
   - Problem: ISO build hangs at "Proceed with download?" prompt
   - Attempted fix: Reverted pacman timeout tweaks (commit 6d82908)
   - Status: **UNCONFIRMED** - No feedback on whether fix resolves the issue
   - Verification needed: Confirm latest ISO builds successfully without stalling

**What Cannot Proceed Until These Are Verified:**
- Missing ISO verification means we're merging untested code to `build` (production branch)
- If Issue 20 isn't fixed, automated ISO builds will continue to fail/hang
- If Issues 19/19B aren't working on ISO, users will experience black screen on boot

---

### Custom Greeter and RDP Implementation Documentation (2025-10-22)

**Documentation Created:** See `/docs/CUSTOM_GREETER_AND_RDP_GUIDE.md` for complete specifications

**Summary:**
The session picker UX issue (regreet showing session selector even when only one session available) has been researched and documented. Key findings:

**Session Picker Issue (regreet limitation):**
- **Problem**: regreet displays session picker even with single session (issue #57 open in regreet, not implemented)
- **Research**: Analyzed all major greeters (regreet, gtkgreet, qtgreet, agreety, cosmic-greeter) - NONE have built-in option to skip picker
- **Current Solution**: Using regreet with session filtering via wildcards + systemd override + pacman hook
  - Removes unwanted sessions from disk, preventing picker from showing alternatives
  - Sessions stay removed on every boot and after package updates
- **Future Solution Options (documented in guide)**:

**Option 1: Custom Minimal Greeter** ✅ RECOMMENDED
- Effort: 7-12 hours for minimal version (auto-select single session)
- Timeline: 1-2 days
- Benefit: Solves session picker issue directly, gives full UX control
- Implementation: Rust + greetd IPC protocol (see guide for code template)
- Can be extended later (fingerprint auth, themed UI, etc.)

**Option 2: Patch regreet Source**
- Effort: 5-10 hours
- Maintenance burden: Higher (must track upstream changes)
- Benefit: Works with official regreet, reduces custom code

**Option 3: Wait for regreet issue #57**
- Effort: 0 hours
- Risk: No guarantee issue will be implemented
- Passive approach

**Wayland RDP Status:**
- **Current**: Using wayvnc (VNC) for remote access
- **RDP Status**: wlroots dropped RDP support in 2022 (was experimental)
- **Implementation Options** (documented in guide):

| Option | Effort | Recommendation |
|--------|--------|-----------------|
| Port Weston RDP backend | 300-500+ hours | ❌ Not realistic |
| Implement RDP from scratch | 500+ hours | ❌ Not realistic |
| Use FreeRDP wrapper | 200-300 hours | ❌ Too expensive |
| Expand wayvnc capabilities | 5-10 hours | ✅ **RECOMMENDED** |

**Recommendation**: Maximize wayvnc (already functional) rather than invest 300+ hours in RDP implementation

**Document Location**: `docs/CUSTOM_GREETER_AND_RDP_GUIDE.md`
- Contains full greetd IPC protocol specification
- Includes Rust implementation template for custom greeter
- Details all RDP options with effort estimates
- Provides references to existing greeter implementations (agreety, gtkgreet source code)

---

### Verification: Default→Dotfiles Pattern for Packages We Added (2025-10-23)

**SCOPE**: Verify that the four packages/configurations WE ADDED follow the Default→Dotfiles architectural pattern documented at the top of this file.

**Packages to Verify**:
1. ⏳ **wayvnc** - Remote access VNC server
2. ⏳ **SSH/openssh** - Remote shell access
3. ⏳ **autologin configuration** - User session autostart
4. ⏳ **greetd/regreet** - Display manager and greeter

**Verification Process for Each Package**:

For each package, check:
- [ ] Are defaults stored in `~/.local/share/omarchy/default/[package]/`?
- [ ] Are user overrides allowed in `~/.config/[package]/`?
- [ ] Does the installer script deploy defaults to the correct location?
- [ ] Does the application/service check user override first, then fall back to defaults?
- [ ] Can users customize without affecting Omarchy defaults?

**If pattern is NOT followed**:
- Move default configs from hardcoded locations to `~/.local/share/omarchy/default/[package]/`
- Update installer scripts to deploy to this location
- Update application/service startup to check user override first
- Document the fix in this section

---

### Future Enhancements (Post v1.0)
- **Multiple Compositor Support**: Allow users to select window manager/compositor during installation
  - Options: Hyprland (current default), Sway, Niri
  - Requires: Default config files for each compositor that are close to current Hyprland config
  - Implementation: Add compositor selection to Advanced mode configurator
  - Note: Keep configs similar to maintain consistent Omarchy experience across compositors

- **evilSteve Theme**: Create custom theme bundled with Omarchy Advanced by default
  - Add to themes/ directory alongside existing themes (tokyo-night, catppuccin, etc.)
  - Include all theme components: hyprlock.conf, mako.ini, alacritty.toml, kitty.conf, etc.
  - Make selectable via Style > Theme menu

### Completed Tasks
- ✅ Investigation of existing codebase architecture
- ✅ Located autologin configuration mechanism
- ✅ Found drive/partition selection utilities
- ✅ Confirmed Hyprland autostart.conf location
- ✅ Examined firewall setup
- ✅ Researched ISO build process and architecture
- ✅ Analyzed configurator and automated script workflow
- ✅ Determined Path A (Full ISO Fork) is required for VM use case
- ✅ **Forked omarchy-iso to stevepresley/omarchy-advanced-iso**
- ✅ Created `feature/advanced-mode` branch in omarchy-advanced-iso
- ✅ Configured git remotes (origin: stevepresley/omarchy-advanced-iso, upstream: omacom-io/omarchy-iso)
- ✅ Set git user config for omarchy-advanced-iso (stevepresley <github@stevepresley.net>)
- ✅ Added CLAUDE.md documentation to omarchy-advanced-iso repository
- ✅ Implemented configurator changes (6 commits):
  - Installation mode selection (Standard/Advanced) as first step
  - Default values for Standard mode
  - Advanced mode prompts section with INSTALLATION_MODE gate
  - Workstation/VM profile selection
  - LUKS encryption prompt with profile-based defaults

### Implementation Complete

**omarchy-advanced-iso repository (`feature/advanced-mode` branch):** 13 commits
- ✅ Installation mode selection (Standard/Advanced) as first step
- ✅ Default values for Standard mode
- ✅ Advanced mode prompts section (gated by INSTALLATION_MODE)
- ✅ Workstation/VM profile selection
- ✅ LUKS encryption prompt with profile-based defaults
- ✅ SSH server prompt with profile-based defaults
- ✅ wayvnc prompt with profile-based defaults
- ✅ Autologin prompt (conditional on LUKS disabled)
- ✅ Summary screen modifications (appends advanced choices)
- ✅ Conditional LUKS JSON generation for archinstall
- ✅ Advanced state file generation
- ✅ Automated script modifications to copy state file
- ✅ Git configuration and documentation (CLAUDE.local.md)

**omarchy repository (`feature/omarchy-advanced` branch):** 5 commits
- ✅ SSH configuration script (install/config/ssh.sh)
- ✅ wayvnc configuration script (install/config/wayvnc.sh)
- ✅ Autologin configuration script (install/config/autologin.sh)
- ✅ Firewall modifications for VNC port (install/first-run/firewall.sh)
- ✅ Main installer integration (install.sh + install/config/all.sh)

**Total:** 18 commits across both repositories

## Building the ISO

### Prerequisites

1. **Docker** - The ISO build runs in a Docker container (archlinux/archlinux:latest)
2. **Git** - To clone repositories and manage submodules
3. **gum** (optional) - For the interactive boot prompt after build

### Build Process

The ISO is built using the `omarchy-advanced-iso-make` script which:
1. Updates git submodules (archiso)
2. Runs a Docker container with Arch Linux
3. Installs archiso and build dependencies
4. Clones the omarchy repository (specified by environment variables)
5. Downloads all required packages for offline installation
6. Builds the ISO using archiso
7. Outputs to `./release/` directory

### Build Commands

**To build with our custom branches:**

```bash
cd /Volumes/Storage/Projects/omarchy-advanced-iso

# Set environment variables to use our forked repositories
export OMARCHY_INSTALLER_REPO="stevepresley/omarchy-advanced"

# For production builds, use 'build' branch (stable)
export OMARCHY_INSTALLER_REF="build"

# For testing unreleased features, use specific feature branch
# export OMARCHY_INSTALLER_REF="feature/my-feature"

# Build the ISO
./bin/omarchy-advanced-iso-make
```

**Optional flags:**
- `--no-cache` - Don't use cached packages (forces fresh download)
- `--no-boot-offer` - Don't prompt to boot the ISO after build

**Output:**
- ISO file will be in: `./release/omarchy-YYYY-MM-DD-feature-omarchy-advanced.iso`

### Important Notes

1. **The build must run from the `build` branch** in omarchy-advanced-iso (or `feature/*` for testing)
2. **Environment variables tell it to use our omarchy fork** (`stevepresley/omarchy-advanced` branch `build`)
3. **Build happens in Docker** - requires Docker daemon running
4. **Build time** - First build can take 15-30 minutes (downloading packages)
5. **Disk space** - Requires ~5-10GB for packages and build artifacts
6. **Cached builds** - Subsequent builds are faster (uses cached packages from `~/.cache/omarchy/`)

### Verification Before Building

Make sure you're on the correct branches:

```bash
# Check omarchy-advanced-iso branch
cd /Volumes/Storage/Projects/omarchy-advanced-iso
git branch --show-current  # Should show: build (or feature/* for testing)

# Check omarchy-advanced branch (not required for build, but for reference)
cd /Volumes/Storage/Projects/omarchy-advanced
git branch --show-current  # Should show: build (or feature/* for testing)
```

### After Build

The script will offer to boot the ISO in a VM (requires `omarchy-advanced-iso-boot` which uses QEMU). You can also:
- Test in VirtualBox: Create new VM and mount the ISO
- Test in VMware: Create new VM and mount the ISO
- Write to USB: Use `dd` or Etcher to create bootable USB

### Testing Strategy

**Configurator Testing:**
- ✅ Syntax validation passed (bash -n)
- ⏳ Interactive testing requires:
  - Arch Linux environment
  - `gum` tool installed
  - Omarchy helpers available
- **Test Plan:**
  1. Build ISO with modified configurator
  2. Boot ISO in VM (VirtualBox/VMware/QEMU)
  3. Test Standard mode flow (should match existing behavior)
  4. Test Advanced mode Workstation profile (with LUKS)
  5. Test Advanced mode VM profile (without LUKS, with SSH/VNC)
  6. Verify state file is generated correctly
  7. Verify archinstall JSON is correct (with/without LUKS)

**When to test:**
- After completing automated script modifications
- After completing omarchy installer modifications
- Before creating pull request

### Next Steps (Implementation Phase)

**PRIORITY FOCUS:** Encryption, SSH, and wayvnc first. Partition selection deprioritized for later.

**Phase 1: ISO Configurator Modifications** (stevepresley/omarchy-advanced-iso)

**CRITICAL ARCHITECTURE:** Standard/Advanced mode selection is THE VERY FIRST STEP before any other prompts. This is a mode gate that determines whether user sees any advanced options throughout the entire flow.

**Configurator Flow:**
```
Step 0: [Standard or Advanced?] ← NEW, FIRST STEP, sets INSTALLATION_MODE variable
Step 1: Keyboard Layout (both modes)
Step 2: User Account Setup (both modes)
Step 3: Disk Selection (both modes)
        ↓ (if INSTALLATION_MODE="Advanced")
        → [FUTURE: Partition selection - deprioritized for now]
        → Summary screen (existing, both modes show user/disk info)
Step 4: ONLY if INSTALLATION_MODE="Advanced":
        → Profile Selection (Workstation/VM)
        → LUKS Encryption? (defaults based on profile)
        → Enable SSH? (defaults based on profile)
        → Enable wayvnc? (defaults based on profile)
        → Enable autologin? (conditional: only ask if LUKS=N)
Step 5: Generate JSON
        - Standard mode: ALWAYS include LUKS (existing behavior)
        - Advanced mode: conditionally include LUKS based on user choice
Step 6: Generate state file with ALL choices (both modes)
        - Standard mode state: install_mode=Standard, enable_luks=true, enable_ssh=false, enable_wayvnc=false, enable_autologin=true
        - Advanced mode state: install_mode=Advanced, plus user's choices
```

**KEY ARCHITECTURAL POINTS:**
1. Standard mode NEVER shows SSH/VNC/autologin/profile prompts - these are gated by `if [[ "$INSTALLATION_MODE" == "Advanced" ]]`
2. Standard mode ALWAYS has LUKS enabled (existing behavior, no changes)
3. The EXISTING summary screen (lines 106-125) is MODIFIED to show advanced choices IF in Advanced mode
   - Standard mode: shows existing fields (Username, Password, Full name, Email, Hostname, Timezone, Keyboard)
   - Advanced mode: APPENDS additional rows (Profile, LUKS, SSH, wayvnc, Autologin) to the same table
4. State file is ALWAYS generated (both modes) so omarchy installer knows what to configure
5. There is NO second summary screen - we modify the existing one to conditionally show more rows

**Implementation Tasks:**
1. ✅ Clone the forked repository locally
2. ✅ Analyze the configurator script's JSON generation logic
3. Add Standard vs Advanced mode prompt **AS THE VERY FIRST STEP** (before keyboard layout)
4. Set `ADVANCED_MODE` variable (true/false) to gate all subsequent advanced prompts
5. ~~Add partition selection capability~~ **[DEPRIORITIZED - implement later]**
6. Add Workstation vs VM profile selection (only if ADVANCED_MODE=true, after disk selection)
7. Add optional LUKS encryption prompt (only if ADVANCED_MODE=true, defaults: Workstation=Y, VM=N)
8. Add SSH enable/disable prompt (only if ADVANCED_MODE=true, defaults: Workstation=N, VM=Y)
9. Add wayvnc enable/disable prompt (only if ADVANCED_MODE=true, defaults: Workstation=N, VM=Y)
10. Add autologin enable/disable prompt (only if ADVANCED_MODE=true and LUKS=N)
11. Modify JSON generation to conditionally include/exclude LUKS config (lines 304-310)
12. Create state file `/tmp/omarchy-advanced-state.json` with all choices (only if ADVANCED_MODE=true)
13. Test configurator in "dry" mode with both Standard and Advanced flows

**Phase 2: Automated Script Modifications** (stevepresley/omarchy-advanced-iso)
1. Modify `.automated_script.sh` to copy state file into new system
2. Set `OMARCHY_ADVANCED_STATE` environment variable for installer
3. Test script modifications

**Phase 3: Omarchy Installer Modifications** (stevepresley/omarchy)
1. Add LUKS detection in preflight for manual installations
2. Add SSH configuration script
3. Add wayvnc configuration script
4. Add autologin control script
5. Modify firewall script for conditional VNC port
6. Modify main installer to read state file and orchestrate advanced features
7. Test manual installation flow

**Phase 4: Integration & Testing**
1. Build ISO with custom omarchy installer reference
2. Test Standard mode (should work like current ISO)
3. Test Advanced mode Workstation profile (with LUKS)
4. Test Advanced mode VM profile (without LUKS, with SSH/VNC)
5. Test manual installation with LUKS detection
6. Document usage and create release notes

### Key Questions - RESOLVED
1. ✅ Does the Omarchy ISO include a custom archinstall configuration? **YES** - The configurator script generates archinstall JSON files
2. ✅ Where is the archinstall configuration that sets up LUKS encryption? **In the configurator script** - generates `user_configuration.json` with LUKS hardcoded
3. ✅ Is there a separate archiso build repository? **YES** - `omacom-io/omarchy-iso` (now forked to `stevepresley/omarchy-advanced-iso`)
4. ✅ Can we modify the ISO generation to include our advanced mode prompts? **YES** - Modify the configurator script in our fork

### ISO Build Process & Architecture

**Repository Structure:**
- **Main ISO Repository**: `omacom-io/omarchy-iso` (separate from `basecamp/omarchy`)
- **Build Tool**: `./bin/omarchy-iso-make` → outputs to `./release/`
- **Customization**: Uses environment variables `OMARCHY_INSTALLER_REPO` and `OMARCHY_INSTALLER_REF` to specify which fork/branch to include

**Key Components:**
1. **Omarchy Configurator** (`configs/airootfs/root/configurator`)
   - Bash script using `gum` for interactive prompts
   - Collects: keyboard layout, user credentials, hostname, timezone, disk selection
   - Generates JSON files for archinstall:
     - `user_credentials.json` - encrypted password and user array
     - `user_configuration.json` - disk partitioning, LUKS config, kernel, mirrors, locale
   - LUKS encryption is ALWAYS enabled in generated config (2GB boot FAT32 + remainder Btrfs/zstd/LUKS)
   - Does NOT directly call archinstall - just generates config files

2. **Automated Script** (`configs/airootfs/root/.automated_script.sh`)
   - Runs on tty1 only
   - Workflow: run configurator → install arch (via archinstall) → install omarchy → reboot
   - Calls `archinstall` with pre-generated JSON configs
   - Chroots into new system and runs omarchy installer from `/home/USERNAME/.local/share/omarchy/install.sh`

**Installation Flow:**
```
ISO Boot → .automated_script.sh checks tty1
         ↓
     Run configurator (user prompts + JSON generation)
         ↓
     Run archinstall (with JSON configs - LUKS always enabled)
         ↓
     Chroot into new system
         ↓
     Run omarchy installer (install.sh)
         ↓
     Reboot
```

**CRITICAL INSIGHT:** The configurator currently has NO option to disable LUKS encryption - it's hardcoded into the JSON generation. To add optional encryption, we need to modify the configurator script itself.

### Completed Research
- ✅ Located and analyzed omarchy-advanced-iso repository structure
- ✅ Examined configurator script - identified where LUKS config is generated
- ✅ Examined automated script - understood full installation workflow
- ✅ Confirmed archinstall is called with JSON configs, not interactively

## IMPLEMENTATION APPROACH

Based on our research, we have **two implementation paths**:

### Path A: ISO-Level Implementation (Full Advanced Mode)
Modify the `omacom-io/omarchy-iso` repository (forked to `stevepresley/omarchy-advanced-iso`) to add advanced mode prompts BEFORE archinstall runs.

**Pros:**
- Complete control over all advanced options (partition selection, encryption, etc.)
- Clean separation of concerns (ISO handles disk setup, omarchy handles configuration)
- Users get advanced options immediately when booting the ISO

**Cons:**
- Requires forking and maintaining a separate ISO repository
- More complex build/test cycle (requires building full ISOs)
- Need to understand archinstall JSON format deeply

**Changes Required:**
1. Fork `omacom-io/omarchy-iso` to `stevepresley/omarchy-advanced-iso`
2. Modify `configs/airootfs/root/configurator`:
   - Add "Standard" vs "Advanced" mode prompt at start
   - In Advanced mode, add partition selection (not just full disk)
   - Add "Workstation" vs "VM" profile selection
   - Add optional LUKS encryption (modify JSON generation conditionally)
   - Create state file with choices: `/tmp/omarchy-advanced-state.json`
3. Modify `.automated_script.sh`:
   - Copy state file into new system before chroot
   - Pass state file path to omarchy installer
4. Build ISO with `OMARCHY_INSTALLER_REPO=stevepresley/omarchy OMARCHY_INSTALLER_REF=feature/omarchy-advanced`

### Path B: Post-Install Implementation (Omarchy-Only Changes)
Keep ISO as-is (always uses LUKS), add advanced options only in the omarchy installer phase.

**Pros:**
- Simpler to implement (only modify `basecamp/omarchy` fork)
- Easier to test (can run installer on existing Arch systems)
- No ISO build/maintenance required

**Cons:**
- **CRITICAL FLAW**: LUKS encryption is always enabled, requiring console password entry on every boot
- **This breaks the VM use case**: SSH/VNC remote access is useless if someone must physically type the LUKS password at console before the system can boot
- Can't do partition selection (ISO always uses full disk)

**CONCLUSION: Path B is NOT VIABLE for the VM use case**

### RECOMMENDED APPROACH: Path A (Full ISO Fork)

Given the requirement that VMs must boot unattended without console interaction, **we MUST fork the ISO repository** to make LUKS optional.

**Why this is necessary:**
- VM happy path requires: boot → autologin (optional) → SSH/VNC accessible
- With LUKS enabled: boot → **[BLOCKED: waiting for password at console]** → can't proceed
- Remote access (SSH/VNC) is completely blocked until someone physically types the encryption password
- This defeats the entire purpose of the VM configuration

**Implementation Plan:**

**IMPORTANT ARCHITECTURAL DECISION:**
- LUKS encryption selection happens in the **ISO configurator only** (before archinstall runs)
- The omarchy installer (`install.sh`) **never handles encryption setup**
- Encryption must be configured BEFORE omarchy runs (either via our ISO configurator or manual archinstall)

**For ISO Installation:**
1. Fork `omacom-io/omarchy-iso` to `stevepresley/omarchy-advanced-iso`
2. Modify `configs/airootfs/root/configurator`:
   - Add "Standard" vs "Advanced" mode prompt at the beginning
   - In Advanced mode:
     - Add partition selection (not just full disk) - **enables dual-boot/testing scenarios**
     - Add "Workstation" vs "VM" profile selection
     - Add optional LUKS encryption prompt (default: Y for Workstation, N for VM)
     - Conditionally generate archinstall JSON with or without LUKS config
     - Create state file: `/tmp/omarchy-advanced-state.json` with user choices
3. Modify `.automated_script.sh`:
   - Copy state file to `/mnt/omarchy-advanced-state.json` before chroot
   - Pass state file path to omarchy installer via environment variable `OMARCHY_ADVANCED_STATE`

**For Manual Installation (boot.sh / install.sh):**
4. Add `install/preflight/luks-check.sh`:
   - Detect if root filesystem is LUKS-encrypted (check `/proc/mounts` for `/dev/mapper/` or `lsblk -f` for crypto_LUKS)
   - If LUKS detected, display warning and prompt user to confirm:
     ```
     WARNING: LUKS disk encryption detected!

     Omarchy's VM advanced mode (SSH/VNC remote access) requires
     unattended boot without encryption password entry.

     Your system uses LUKS encryption, which will require console
     password entry on every boot. This prevents headless/remote operation.

     If you need VM/remote access features, you must reinstall without
     LUKS encryption using archinstall before running Omarchy.

     Continue with installation anyway? (y/N)
     ```
   - If user selects 'N', exit installer
   - If 'Y', continue but disable advanced VM features
   - **OUT OF SCOPE**: Removing/disabling existing LUKS encryption

**For Omarchy Installer (both ISO and manual):**
5. Modify `install.sh`:
   - Source advanced state file if `OMARCHY_ADVANCED_STATE` is set
   - Read user choices (profile, SSH, VNC, autologin preferences)
   - Pass to configuration scripts via environment variables
6. Add `install/config/ssh.sh` - conditionally install/enable openssh
7. Add `install/config/wayvnc.sh` - conditionally install/configure wayvnc + virtual display
8. Add `install/config/autologin.sh` - conditionally disable autologin
9. Modify `install/first-run/firewall.sh` - conditionally add VNC port 5900
10. Add end-of-install message with VNC connection info (if wayvnc enabled)

**For ISO Build:**
11. Build custom ISO with `OMARCHY_INSTALLER_REPO=stevepresley/omarchy-advanced OMARCHY_INSTALLER_REF=build`

**This is the only viable path forward for the VM use case.**

### Architecture Summary: Who Handles What

**ISO Configurator (omarchy-advanced-iso repo):**
- ✅ Disk/partition selection
- ✅ LUKS encryption decision (Y/N)
- ✅ Workstation vs VM profile selection
- ✅ Generates archinstall JSON config
- ✅ Passes state file to omarchy installer

**Omarchy Installer (omarchy-advanced repo):**
- ✅ SSH installation/configuration
- ✅ VNC installation/configuration
- ✅ Autologin enable/disable
- ✅ Firewall rules (SSH/VNC ports)
- ✅ LUKS detection and warning (manual install only)
- ❌ NEVER handles LUKS setup/removal (out of scope)

**Manual Installation Workflow:**
```
User runs archinstall manually → configures LUKS (or not) → installs base Arch
                                                              ↓
                                  User runs: curl -sL omarchy.org | bash
                                                              ↓
                                       Omarchy detects LUKS (if present)
                                                              ↓
                             If LUKS found: warn user, disable VM features
                                                              ↓
                              If no LUKS: offer full advanced mode options
                                                              ↓
                                         Install continues normally
```

**ISO Installation Workflow:**
```
Boot ISO → Configurator prompts (Standard/Advanced mode)
                                          ↓
                    [Advanced Mode: partition + profile + LUKS choice]
                                          ↓
                          Configurator generates JSON + state file
                                          ↓
                            archinstall runs (with or without LUKS)
                                          ↓
                        State file copied into new system at /root/
                                          ↓
                    Omarchy installer reads state file, applies settings
                                          ↓
                              System reboots (with SSH/VNC if enabled)
```
