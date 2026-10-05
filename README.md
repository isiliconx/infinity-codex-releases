# Infinity

Give your MCP host control of provisioned computers through one stable gateway.
Connect once with its **MCP URL** and **Owner password**, then select a computer.
A project or Git repository is unnecessary. Application source stays private.

[Release 1.0.11](https://github.com/isiliconx/infinity-codex-releases/releases/tag/v1.0.11)
supports **Linux x64** and includes its Node runtime. Windows, macOS, and arm64
binaries await native validation. Native Linux desktop input is unavailable;
file, command, and configured browser tools can use the account's OS permissions.

## Install a computer

[Set up your gateway](#operator-setup) once before installing targets. Each target
needs an expiring enrollment file, or your gateway address and a one-use code.
Targets do not need GitHub, ngrok, or Cloudflare accounts.

Run this in the target's terminal:

```sh
curl -fsSL https://github.com/isiliconx/infinity-codex-releases/releases/latest/download/install.sh | sh
```

The installer verifies the executable, asks for the gateway address and a masked
enrollment code, confirms computer access, and starts its persistent agent.
It uses the current account's permissions and normal OS approvals. Existing
identity and access policy are preserved. You can close the installation terminal
when it reports completion. Connection records are encrypted on the target and
sent to the gateway; cloud backup is reported as pending until R2 readback succeeds.

## Install from USB

Download `infinity-linux-x64-usb.zip` from the [latest release](https://github.com/isiliconx/infinity-codex-releases/releases/latest)
and extract it onto the stick. Put the gateway's prepared `enrollment.json`
beside `GO.sh`. On each target, open that folder and run:

```sh
sh GO.sh
```

The launcher verifies and copies Infinity to the computer, confirms access,
enrolls it, registers startup, and writes its encrypted connection record to
`connections/` on the USB. **Remove the USB when completion says it is safe.**
Without a prepared enrollment file, it asks for the address and one-use code.
Used or expired tickets must be replaced on the gateway. USB insertion alone
does not bypass the operating system's execution approval.

The agent runs from the host copy after USB removal. Connecting requires internet,
a running gateway, and an awake target. Linux uses a user service with normal
approval for lingering after logout; otherwise it uses desktop login startup.
Installation does not change sleep settings.

## Operator setup

<details>
<summary>Configure the gateway, private cloud records, and enrollment once</summary>

Use your existing [ngrok account](https://dashboard.ngrok.com/) and its assigned
domain. The gateway needs an always-on Linux x64 computer or server you control.
One ngrok agent serves every target through the same domain; traffic shares the
[free-plan quotas](https://ngrok.com/docs/pricing-limits/free-plan-limits).
Storage does not replace the running gateway.

Install the operator executable without enrolling that computer:

```sh
curl -fsSL https://github.com/isiliconx/infinity-codex-releases/releases/latest/download/install.sh | INFINITY_INSTALL_ONLY=1 sh
```

On your own computer, generate the record encryption keys:

```sh
~/.local/bin/infinity connection keys --private recipient-private.pem --public recipient-public.pem
```

Keep and back up `recipient-private.pem` on your own computer. Copy only
`recipient-public.pem` to the gateway. Install the same executable there and
initialize it using your assigned domain:

```sh
~/.local/bin/infinity gateway init --url https://YOUR-DOMAIN.ngrok-free.app --recipient recipient-public.pem
~/.local/bin/infinity gateway serve
```

The terminal shows the gateway's MCP URL and Owner password. Save that password
privately. On the gateway, install/configure ngrok using its dashboard instructions,
keep its authtoken local, and start the tunnel in another terminal:

```sh
ngrok http 7677 --url https://YOUR-DOMAIN.ngrok-free.app
```

Keep both processes running, or supervise them with the gateway host's service
manager. Infinity listens only on loopback. Target installers register their
own startup automatically; they do not register the operator's gateway service.

### Private cloud records

Create a [Cloudflare account](https://dash.cloudflare.com/sign-up), enable
[R2](https://developers.cloudflare.com/r2/get-started/), and create a bucket such
as `infinity-connections`. Keep public access disabled. Create an
[R2 credential](https://developers.cloudflare.com/r2/api/tokens/) with Object
Read & Write permission restricted to this bucket. R2 activation includes its
subscription checkout; [included usage and pricing](https://developers.cloudflare.com/r2/pricing/)
apply.

On the gateway, put these values in a private `r2.json` file:

```json
{
  "accountId": "YOUR_CLOUDFLARE_ACCOUNT_ID",
  "bucket": "infinity-connections",
  "accessKeyId": "YOUR_R2_ACCESS_KEY_ID",
  "secretAccessKey": "YOUR_R2_SECRET_ACCESS_KEY"
}
```

Import it, then restart the gateway:

```sh
~/.local/bin/infinity gateway r2 --file r2.json
~/.local/bin/infinity gateway serve
```

Keep the import file private and remove it after securing its backup. Do not
paste passwords, authtokens, cloud secrets, or private keys into chat. Targets
receive none of these global credentials. Failed uploads stay queued on the
gateway and retry; only encrypted records enter R2.

### Prepare enrollment and connect

On the gateway, create enough one-use tickets for your computers:

```sh
~/.local/bin/infinity gateway tickets --out enrollment.json --count 10 --hours 24
```

Keep this file private. Copy it beside the USB launcher, or use one of its
`tickets` values as the one-liner's enrollment code. A prepared file can also be
passed with `~/.local/bin/infinity provision --enrollment-file enrollment.json`.
Tickets authorize enrollment and cannot control existing computers.

Add the gateway's `/mcp` URL to your MCP host and enter its Owner password when
asked. The host uses `computer_list` to select a target, `computer_tools` to
inspect its tools, and `computer_call` to invoke one with a fresh UUID operation
id. `computer_operation` checks a prior receipt. Uncertain operations are never
automatically replayed after timeout or disconnect.

### Recover and revoke

Use USB copies, download ciphertext from your private R2 bucket, or export it
on the gateway with `~/.local/bin/infinity gateway export --out-dir records`.
Decrypt only on your own computer:

```sh
~/.local/bin/infinity connection decrypt --record COMPUTER-ID.json --key recipient-private.pem --out connection.json
```

This private file contains the MCP URL, computer id/label, and its local Owner
password for recovery. The gateway Owner password is stored separately. Revoke
one target on the gateway with
`~/.local/bin/infinity gateway revoke --computer COMPUTER-ID`.
Other computers retain their credentials.

</details>

Downloads contain compiled executables, small installers, checksums, and license
notices. No application source checkout is distributed. Release notes distinguish
local fixture checks from pending native platform and live cloud validation.
