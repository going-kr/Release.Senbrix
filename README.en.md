<p align="right"><a href="README.md">한국어</a> | <b>English</b></p>
<p align="center">
  <img src="docs/images/logo.png" width="120" alt="Senbrix"/>
</p>
<h1 align="center">Senbrix PLC</h1>
<p align="center">Ladder + C# development environment that turns a Raspberry Pi into a <b>PLC</b></p>
<p align="center">
  <a href="https://github.com/going-kr/Release.Senbrix/releases/latest"><b>⬇ Download Senbrix-win-Setup.exe</b></a>
  &nbsp;·&nbsp; Windows 10/11 x64 &nbsp;·&nbsp; Korean / English UI
</p>

---

This repository distributes **installers and auto-update artifacts only**. The source code is maintained privately.

## What is Senbrix

**Senbrix** is [Going](https://github.com/going-kr)'s Raspberry Pi PLC toolchain. It treats **ladder logic (LD)** and **C#** as one program: ladder rungs and hand-written C# share the same `partial class App`, the same symbols and the same IntelliSense. The build output is deployed over the network to the **Senbrix Runtime** on the Pi (10 ms scan cycle), and the same connection carries **live monitoring and diagnostics**.

<p align="center"><img src="docs/images/ladder.png" width="900" alt="Ladder editor"/></p>

## Components: editor + runtime

Senbrix has two parts that are **installed separately**. This release contains the editor only.

| Component | Runs on | Role |
|---|---|---|
| **Senbrix Editor** (this release) | Windows PC | Ladder/symbol/C# editing, lint, build (`dotnet build`), runtime discovery and deploy, live monitoring and diagnostics, MCP server |
| **Senbrix Runtime** | Raspberry Pi | Executes the deployed app on a 10 ms scan cycle. Talks to the editor over HTTP (5557), TextComm (5555) and mDNS. Runs as a systemd service; persists/restores keep memory and drives CAN IO expansion boards, main-board GPIO and Modbus communication |

See [Runtime install (Raspberry Pi)](#runtime-install-raspberry-pi) below. The editor's **Deploy** pushes the *app (build output)* to the runtime; it does not install the runtime itself.

## Features

### Ladder editor: familiar notation, symbol-based
Place contacts, coils, functions (TON/TOFF/TMON/TAON/CTU/CTD/CTR/SETOUT/RSTOUT/MCS/DIST/UNIT/WXCHG…), parallel branches and edge detection with keyboard and mouse. Write against **symbol names** instead of raw addresses (P0, M10, D127…). On save, a **static linter** flags double coils, broken rungs, latches with no release, counters with no reset, undefined names, read-only symbols and read-before-write.

### Symbol table
Name ↔ address mapping, description, unit, access rights, and **keep (retentive) symbols**: one checkbox and the value is persisted by the runtime and restored after a reboot.

<p align="center"><img src="docs/images/symbols.png" width="900" alt="Symbols"/></p>

### C# code: one program with the ladder
Write C# in `Setup()` / `Loop()` and use the same memory areas (P·M·T·C·D·WP·WM) and symbols the ladder uses. User C# runs on a separate task, so the 10 ms ladder cycle stays deterministic. A pure control/signal/metering library (PID with auto-tuner, filters, flow metering, FFT) is referenced by default.

<p align="center"><img src="docs/images/code.png" width="900" alt="C# code"/></p>

### Build & deploy: the output is a plain .NET project
C# sources are regenerated from ladder and symbols on every build and compiled with `dotnet build`. Compiler errors are **mapped back to ladder cell coordinates**. The build output is deployed with one click to a Raspberry Pi runtime discovered over mDNS, and starts automatically.

### Live monitoring & diagnostics
Contacts, coils, timers and word values are shown **live on the ladder**. In diagnostics mode you pick the addresses you allow, then **force** or write only those; anything else is rejected by the runtime (fail-closed). Diagnostics is disarmed automatically when the connection drops.

<p align="center"><img src="docs/images/monitor.png" width="900" alt="Live monitoring"/></p>
<p align="center"><img src="docs/images/diag-arm.png" width="445" alt="Start diagnostics: write permission"/></p>

### Hardware: main-board GPIO + IO expansion boards
Carrier-board GPIO is described in XML and mapped to IN/OUT slots; CAN-bus IO expansion boards (IO-8) attach by number. The board configuration is stored in the project and read as-is by the runtime.

<p align="center"><img src="docs/images/project.png" width="900" alt="Project · board configuration"/></p>

### Communication: Modbus RTU/TCP slave · master
The slave exposes PLC memory directly; the master reads and writes remote devices through monitor (polling block) and bind (remote↔local mapping) tables. Settings UI is generated from the properties each plugin declares.

<p align="center"><img src="docs/images/modbus-tcp.png" width="520" alt="Modbus TCP settings"/></p>

### AI workflow (MCP)
Senbrix embeds an **MCP server**, so AI coding tools such as Claude Code and Codex read and write ladder, symbols, communication and boards through tool calls, and can build and deploy. Interview → design → plan → implementation → verification progress is shown on the AI page, and in diagnostics mode the AI reads runtime values and experiments only within the allowed range.

<p align="center"><img src="docs/images/ai.png" width="900" alt="AI progress"/></p>

## Requirements

| | Requirement |
|---|---|
| Editor PC | Windows 10/11 x64. **.NET 9 SDK** (the build runs `dotnet build`). The desktop runtime is installed by the setup if missing |
| Runtime device | Raspberry Pi (64-bit Linux) + .NET 9 runtime + Senbrix Runtime (see install section below). Same network as the editor (ports 5557/5555, mDNS) |

## Editor install (Windows)

1. Download **`Senbrix-win-Setup.exe`** from the [latest release](https://github.com/going-kr/Release.Senbrix/releases/latest) and run it.
2. The installer is not code-signed, so Windows SmartScreen may warn → **"More info" → "Run anyway"**.
3. If the .NET 9 Desktop Runtime is missing, the installer downloads and installs it (an admin prompt may appear once).
4. Installs per-user under `%LocalAppData%\Senbrix`; no admin rights required.

## Runtime install (Raspberry Pi)

Install the **Senbrix Runtime**, the target the editor deploys to, once on the Raspberry Pi. One line in the Pi's shell (Raspberry Pi OS, 64-bit recommended, 32-bit works):

```bash
curl -sSL https://github.com/going-kr/Release.Senbrix/releases/latest/download/install-runtime.sh | sudo bash
```

What the script does:
1. Installs the **.NET 9 ASP.NET Core runtime** to `/opt/dotnet` (official `dotnet-install.sh`, arm64/arm32 detected, skipped if present)
2. Downloads **`Senbrix-runtime-x.y.z-linux.tar.gz`** from the release and installs it to `/opt/senbrix` (`Apps/`, `Logs/` and `appsettings.json` are preserved on reinstall/update)
3. Creates the dedicated user `senbrix` (gpio, dialout groups), registers and starts the **systemd service `senbrix-runtime`**, prints status and IP

Options: `sudo bash -s -- --version 0.9.0` (pin a version; use the same version as the editor) · `--tarball ./file.tar.gz` (offline, pre-downloaded file) · `--no-dotnet` (skip the .NET install).
**Updating** the runtime is the same command again. Uninstall: `sudo systemctl disable --now senbrix-runtime && sudo rm -rf /opt/senbrix /etc/systemd/system/senbrix-runtime.service`.

After install:
- **Network**: put the Pi on the same network as the editor PC; if a firewall is active, open **5557 (HTTP), 5555 (TextComm) and 5353/UDP (mDNS)**.
- **Verify**: click the connection icon at the bottom of the editor → the Pi's hostname appears in **Connect Device** (enter the IP manually if not). **Deploy** then sends the build output and the runtime starts the app immediately.
- Logs: `journalctl -u senbrix-runtime -f`; settings: `/opt/senbrix/appsettings.json` (CAN IO expansion boards: `Runtime:CanPort`, e.g. `can0`).
- If the editor is newer than the runtime, deploy is rejected and the status bar says a runtime update is required → run the command above to update.
- The runtime API is currently unauthenticated. Operate it **only on an isolated equipment network**.

<details>
<summary>Manual install (without the script)</summary>

```bash
# .NET 9 ASP.NET Core runtime
curl -sSL https://dot.net/v1/dotnet-install.sh | sudo bash /dev/stdin --channel 9.0 --runtime aspnetcore --install-dir /opt/dotnet
sudo ln -sf /opt/dotnet/dotnet /usr/local/bin/dotnet
# user, folder, files
sudo useradd --system --no-create-home senbrix
sudo mkdir -p /opt/senbrix && sudo tar -xzf Senbrix-runtime-x.y.z-linux.tar.gz -C /opt/senbrix
sudo chown -R senbrix:senbrix /opt/senbrix
```
`/etc/systemd/system/senbrix-runtime.service`:
```ini
[Unit]
Description=Senbrix Runtime (PLC)
Wants=network-online.target
After=network-online.target

[Service]
Type=notify
User=senbrix
WorkingDirectory=/opt/senbrix
Environment=DOTNET_ROOT=/opt/dotnet
ExecStart=/opt/dotnet/dotnet /opt/senbrix/Senbrix.Runtime.dll
Restart=always
RestartSec=5
SyslogIdentifier=senbrix-runtime

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload && sudo systemctl enable --now senbrix-runtime
```
</details>

## Update

The installed app checks quietly for a new version at startup; use **Help › Check for Updates** to download and restart. You never need to come back to this page.

## Release assets

| File | Purpose |
|---|---|
| `Senbrix-win-Setup.exe` | **Editor: the file to download for a first install** |
| `Senbrix-runtime-x.y.z-linux.tar.gz`, `install-runtime.sh` | **Raspberry Pi runtime** and its install script ([Runtime install](#runtime-install-raspberry-pi)). The script downloads the tar.gz itself, so you normally do not download it by hand |
| `Senbrix-x.y.z-full.nupkg`, `*-delta.nupkg` | Auto-update packages. Not for direct download |
| `RELEASES`, `releases.win.json`, `assets.win.json` | Auto-update metadata |

## Feedback

Please file bugs and requests in this repository's [Issues](https://github.com/going-kr/Release.Senbrix/issues).

---

© Going. All rights reserved. Binaries are provided as-is. See [NOTICE.md](NOTICE.md).
