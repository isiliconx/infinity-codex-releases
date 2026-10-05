# Infinity — compiled downloads

Infinity gives MCP hosts authenticated tools on enrolled computers. One stable
gateway MCP URL serves all your computers; connect your host once with its
Owner password, then select a computer. A hosted Cloudflare gateway needs no
always-on operator computer. Targets connect outbound and run under their local
account's OS permissions.

This public repository distributes verified executables, compiled USB bundles,
minimal installers, checksums, and required licenses. Application source and
operator credentials stay private. The executable includes its Node runtime;
targets need no GitHub login, npm installation, or private clone.

[Release 1.0.12](https://github.com/isiliconx/infinity-codex-releases/releases/tag/v1.0.12)
currently covers **Linux x64**. Windows/macOS/arm64 binaries await native
validation. Each release's `RELEASE-TARGETS.txt` lists its available targets.

## One-liner

The operator provides a gateway address and one unused enrollment code. On
Linux x64, run:

```sh
curl -fsSL https://github.com/isiliconx/infinity-codex-releases/releases/latest/download/install.sh | sh
```

The installer verifies the executable, asks for enrollment details, confirms
computer access, registers startup, and waits for a real background connection.
You can close the terminal after completion. Its encrypted connection record is
saved in the hosted gateway's private cloud database. An existing identity and
access policy are preserved when provisioning is rerun.

## USB

Download the Linux x64 USB archive from the
[latest release](https://github.com/isiliconx/infinity-codex-releases/releases/latest),
extract it onto the stick, and put the operator's private `enrollment.json`
beside `GO.sh`. On the target, run `sh GO.sh` and confirm access.

The launcher verifies and copies Infinity onto the computer, enrolls it,
registers startup, and saves an encrypted connection record under `connections/`
on the stick. **Remove the USB when completion says it is safe.** The agent
continues from the computer's own storage. Insertion alone does not bypass OS
execution approval. Copying is offline; enrollment and remote control need
internet. Replace tickets after use or expiry.

## Connection details

For everyday use, keep the **gateway MCP URL and Owner password**. A new target
needs an enrollment code during setup; it never receives the gateway password,
Cloudflare login, or record decryption key. The operator keeps that private key
on their own computer to recover encrypted USB or cloud records.

Targets must be awake and connected. Desktop tools need an interactive session
and the appropriate OS screen/input approvals. Native Linux desktop input is
not yet supported; file, command, and configured browser tools can operate.
Installation does not change sleep settings or bypass elevation.

## Verification

Release 1.0.12 passed compiled Linux OAuth/MCP and core tool checks, the actual
USB consent/startup flow, encrypted export/decryption, USB removal, loopback
gateway restart/reconnect, and live Cloudflare HTTPS/WSS, idle keepalives, cloud
export, and revocation. Anonymous installation from the public URL matched the
verified checksum. No signed-in ChatGPT/Claude conversation or Windows/macOS
native desktop flow was tested.
