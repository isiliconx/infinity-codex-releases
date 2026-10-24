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

[Release 1.0.15](https://github.com/isiliconx/infinity-codex-releases/releases/tag/v1.0.15)
covers **Windows x64 and Linux x64**. Windows uses executable 1.0.15; Linux
retains the unchanged, previously verified 1.0.14 executable. macOS and ARM
binaries await native validation. Each release's `RELEASE-TARGETS.txt` lists its available targets.

## One-liner

The operator provides a gateway address and an enrollment code. A configured
self-hosted gateway can use a permanent standing code. On
Linux x64, run:

```sh
curl -fsSL https://github.com/isiliconx/infinity-codex-releases/releases/latest/download/install.sh | sh
```

On Windows x64, paste this into PowerShell with your self-hosted gateway address
and standing code:

```powershell
& ([scriptblock]::Create((irm 'https://github.com/isiliconx/infinity-codex-releases/releases/latest/download/install.ps1'))) -GatewayUrl 'https://YOUR-GATEWAY' -EnrollmentCode 'YOUR_7_DIGIT_CODE' -Yes
```

This installs under the signed-in account, exchanges the code for a temporary
enrollment file, and starts the background agent without terminal questions.
`-Yes` explicitly selects computer access under that account's permissions.
OS execution and elevation approvals still apply.

The Linux installer verifies the executable, asks for enrollment details, confirms
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

For Windows x64, use its USB archive, put the prepared `enrollment.json` beside
`GO.cmd`, and launch `GO.cmd`. The prepared Windows launcher needs no gateway
address, code, or terminal consent entry. It preserves unrelated files and uses
normal OS permissions.

## Connection details

For everyday use, keep the **gateway MCP URL and Owner password**. A new target
needs an enrollment code during setup; it never receives the gateway password,
Cloudflare login, or record decryption key. The operator keeps that private key
on their own computer to recover encrypted USB or cloud records.

Targets must be awake and connected. Desktop tools need an interactive session
and the appropriate OS screen/input approvals. Linux X11 desktop
observation/input and AT-SPI accessibility controls are included.
The Wayland portal adapter is in preview and requests sharing approval on the
computer screen. Actual GNOME/KDE consent and compositor input remain unverified;
Wayland clipboard and window-only capture are unavailable. X11 Unicode typing can
replace the clipboard when clipboardWrite is enabled and reports that change.
Installation does not change sleep settings or bypass elevation.

## Verification

Release 1.0.14 passed 167 local test files, compiled Linux OAuth/MCP and core tool
checks, the actual
USB consent/startup flow, encrypted export/decryption, USB removal, loopback
gateway restart/reconnect, and native X11 screenshot, scaled mouse/keyboard
input, Unicode clipboard transfer, stale-frame checks and execution receipts.
A gateway call through an actual USB-enrolled agent reached the real isolated
X11 window. The same executable passed a disposable live Cloudflare gateway with native
HTTPS/WSS desktop calls after USB removal, idle keepalives, encrypted
export/decryption and revocation. The validation Worker was deleted. Anonymous installation from the public URL matched the
verified checksum. The compiled executable also passed actual GTK accessibility discovery, semantic
text/click actions and stale/disabled/app-policy checks. Wayland protocol tests
used a private portal fixture with real PipeWire frames; real GTK accessibility
passed on isolated Weston. These do not establish native portal consent or
compositor pointer/keyboard delivery. No signed-in ChatGPT/Claude conversation
or macOS/ARM native flow was tested.

Windows 1.0.15 validation runs on Windows x64. It covers the production build,
PowerShell 5 installer and USB launcher, checksum rejection and file preservation,
packaged OAuth/MCP and core tools, DPAPI settings, registered startup, background
enrollment through a standing code, a gateway-routed fixture-file read, and
Windows capture backend status. This does not establish native desktop input
or a signed-in ChatGPT/Claude conversation on another computer.
