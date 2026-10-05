# Infinity compiled releases

This repository contains public distribution assets for Infinity. Application source stays private. Releases contain compiled executables, minimal installers, offline USB archives, checksums, and license notices. Executables can be reverse engineered.

Each release's `RELEASE-TARGETS.txt` lists the native platforms included. The initial verified release is **Linux x64**, tested on Ubuntu 24.04. Windows, macOS, and arm64 executables will be added in a new version after their native checks pass. The installer preserves an existing installation when a target is unavailable or validation fails.

Install the latest available Linux/macOS target without GitHub login:

```sh
curl -fsSL https://github.com/isiliconx/infinity-codex-releases/releases/latest/download/install.sh | sh
```

The default user installation is `~/.local/bin/infinity`. Use the printed absolute path or add that directory to PATH, then run `infinity setup` from the project folder you want to expose. `infinity quick` starts a temporary user-owned tunnel. Connecting an MCP host requires Infinity's own owner approval; provider accounts and credentials remain yours.

For offline installation, download the matching `infinity-<platform>-<arch>-usb.zip`, extract it onto a stick, and run `GO.sh` (`GO.command` on macOS or `GO.cmd` on Windows when available). The launcher verifies and copies the executable to the host before starting it, so the stick can be removed after copying. The bundle contains no owner credentials or backups.

Linux browser automation is supported through the optional browser backends. Native Linux desktop input is not included. Native Windows/macOS computer-use permissions and behavior require platform verification. Optional browser binaries, Git, external npm plugin prerequisites, and provider access are separate from installation.

Read the release notes for verification limits and outstanding dependency advisories. Check `SHA256SUMS` against downloaded assets. Third-party licenses and notices accompany each release.
