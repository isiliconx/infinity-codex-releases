# Infinity

Public compiled downloads for Infinity. The application source repository stays private.

The current verified release supports **Linux x64** and includes its Node runtime.

```sh
curl -fsSL https://github.com/isiliconx/infinity-codex-releases/releases/latest/download/install.sh | sh
```

In a terminal, the installer starts Infinity. On first use, approve the project
folder it may access. The connection screen shows your **MCP URL** and **Owner
password**. Add the URL to your MCP host and enter the password when asked.
Keep the Infinity terminal open. Reconnect with `~/.local/bin/infinity quick`;
a temporary URL changes after restart, while your saved password stays the same.

For USB, download `infinity-linux-x64-usb.zip` from the [latest release](https://github.com/isiliconx/infinity-codex-releases/releases/latest),
extract it onto the USB, and run `sh GO.sh` from that folder. Infinity verifies
and copies itself to the computer, then opens the same connection screen.
Remove the USB after the copy confirmation. Configuration and passwords stay
on each computer; connecting still requires the internet.

Windows, macOS, and arm64 binaries await native verification. Release pages list
available targets. Downloads contain compiled executables, installers, checksums,
and license notices; no application source checkout is distributed.
