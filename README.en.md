<p align="right"><a href="README.md">한국어</a> | <b>English</b></p>
<p align="center">
  <img src="docs/images/logo.png" width="120" alt="Senbrix"/>
</p>
<h1 align="center">Senbrix PLC</h1>
<p align="center">A ladder + C# development environment that turns a Raspberry Pi into a <b>PLC</b></p>
<p align="center">
  <a href="https://github.com/going-kr/Release.Senbrix/releases/latest"><b>⬇ Download Senbrix-win-Setup.exe</b></a>
  &nbsp;·&nbsp; Windows 10/11 x64 &nbsp;·&nbsp; Korean / English UI
</p>

---

This repository distributes only the editor installer, auto-update artifacts, and the Raspberry Pi runtime package with its install script. The source code is kept private.

> ℹ️ The "Source code (zip / tar.gz)" links at the bottom of every release are added automatically by GitHub. They are a snapshot of this distribution repository (README, images, install script), not the Senbrix source code.

## What is Senbrix

Senbrix is [Going](https://github.com/going-kr)'s Raspberry Pi PLC toolchain. What sets it apart is that ladder logic (LD) and C# live in one program: ladder rungs and hand-written C# share a single `partial class App`, with the same symbols and IntelliSense across both. The build output is deployed over the network to the Senbrix Runtime running on the Pi (10 ms scan cycle), and the same connection carries live monitoring and diagnostics.

<p align="center"><img src="docs/images/ladder.png" width="900" alt="Ladder editor"/></p>

## Components: editor + runtime (+ simulator)

Senbrix comes in two parts, installed and released separately. A simulator is available as well, for trying things without hardware. Three kinds of releases appear on this repository's release page.

- `vX.Y.Z` — the editor (Windows setup and auto-update assets). The "latest release" is always the editor.
- `runtime-vX.Y.Z` — the Raspberry Pi runtime (`Senbrix-runtime-X.Y.Z-linux.tar.gz`). The install script `install-runtime.sh` lives at the repository root, so the one-liner URL never changes.
- `sim-vX.Y.Z` — the simulator (`Senbrix-sim-X.Y.Z-win.zip`). No installer; unzip and run. It is versioned separately from the editor and the runtime, and each release states which runtime it carries.

| Component | Runs on | Role |
|---|---|---|
| **Senbrix Editor** (`vX.Y.Z` releases) | Windows PC | Ladder/symbol/C# editing, lint, build (`dotnet build`), runtime discovery and deploy, live monitoring and diagnostics, MCP server |
| **Senbrix Runtime** (`runtime-vX.Y.Z` releases) | Raspberry Pi | Executes the deployed app on a 10 ms scan cycle. Talks to the editor over HTTP (5557), TextComm (5555) and mDNS. Runs as a systemd service; persists and restores keep memory, and drives CAN IO expansion boards, main-board GPIO and Modbus communication |
| **Senbrix Simulator** (`sim-vX.Y.Z` releases) | Windows PC | Takes a deploy in place of a Raspberry Pi, runs the app, and lets you wire modules to field devices on screen. The editor sees it as an ordinary device |

See [Runtime install (Raspberry Pi)](#runtime-install-raspberry-pi) below. Note that the editor's Deploy pushes the app (the build output) to the runtime; it does not install the runtime itself.

## Features

### Ladder editor
Place contacts, coils, functions (TON/TOFF/TMON/TAON/CTU/CTD/CTR/SETOUT/RSTOUT/MCS/DIST/UNIT/WXCHG and more), parallel branches and edge detection with keyboard and mouse. You write against symbol names rather than raw addresses like P0, M10 or D127. Each save runs a static linter that flags double coils, broken rungs, latches with no release, counters with no reset, undefined names, symbols that are only ever read, read-before-write, and overly complex rungs.

### Symbol table
Maps names to addresses, along with description, unit and access rights. Mark a symbol as keep (retentive) and the runtime persists its value and restores it after a reboot.

<p align="center"><img src="docs/images/symbols.png" width="900" alt="Symbols"/></p>

### C# code
Write C# in `Setup()` and `Loop()` and you get the same memory areas (P·M·T·C·D·WP·WM) and symbols the ladder uses. User C# runs on a separate task, so the 10 ms ladder cycle stays deterministic. A pure control/signal/metering library — PID with auto-tuner, filters, flow metering, FFT — is referenced by default.

<p align="center"><img src="docs/images/code.png" width="900" alt="C# code"/></p>

### Build and deploy
Every build regenerates the C# sources from the ladder and symbols, then compiles with `dotnet build`. The output is a plain .NET project. Compiler errors are traced back to the ladder cell they came from. One click deploys the build to a Raspberry Pi runtime discovered over mDNS, where it starts right away.

### Live monitoring and diagnostics
Contact, coil, timer and word values are shown live on the ladder. In diagnostics mode you pick the addresses you allow, then force or write only those; the runtime rejects anything else (fail-closed). If the connection drops, diagnostics is disarmed automatically.

<p align="center"><img src="docs/images/monitor.png" width="900" alt="Live monitoring"/></p>
<p align="center"><img src="docs/images/diag-arm.png" width="445" alt="Start diagnostics: write permission"/></p>

### Hardware
Carrier-board GPIO is described in XML and mapped to IN/OUT slots; CAN-bus IO expansion boards (IO-8) attach by number. A definition for the ZPi-IO8R carrier board (Pi Zero 2 W; 4 photocoupler inputs, 4 relay outputs) ships built in, ready to pick from the selection list. The board configuration is stored in the project, and the runtime reads it as-is.

<p align="center"><img src="docs/images/project.png" width="900" alt="Project · board configuration"/></p>

### Communication: Modbus RTU/TCP
As a slave, PLC memory is exposed directly; as a master, remote devices are read and written through monitor (polling block) and bind (remote-to-local mapping) tables. The settings UI is generated from the properties each plugin declares.

<p align="center"><img src="docs/images/modbus-tcp.png" width="520" alt="Modbus TCP settings"/></p>

### AI workflow (MCP)
Senbrix has a built-in MCP server, so AI coding tools such as Claude Code and Codex can read and write ladder, symbols, communication and board configuration through tool calls, and can build and deploy as well. The AI page shows progress through the interview, design, plan, implementation and verification phases. In diagnostics mode the AI reads runtime values and experiments only within the range you have allowed.

<p align="center"><img src="docs/images/ai.png" width="900" alt="AI progress"/></p>

### Simulator (trying things without hardware)

You can run a deployed program without a Raspberry Pi or IO modules. The simulator **contains the runtime itself**, so the same scan cycle and the same board drivers run as on real hardware. The only difference is the path the boards talk over — a CAN wire in the real thing.

It appears in the editor's device list as an ordinary device, and you deploy to it as usual. After a deploy, the modules used by the program you just deployed appear on the rail, a switch, sensor or lamp is placed on each channel, and the wiring is drawn. Names from your symbol table become the device labels, and units come along with them.

- Flip a switch or turn a sensor value and the program reacts. Values can be changed while it runs
- You can also place modules and devices yourself and click terminals to wire them. Incompatible pairs are refused
- Power, ground and COM count as connected without drawing a wire. Which common a terminal ties to is your choice, per terminal
- Board values and wire values are shown side by side

There is no installer. Unzip `Senbrix-sim-X.Y.Z-win.zip` and run `SenbrixSim.exe` (.NET not required). Use it on the same PC as the editor, or on another PC on the same network.

The simulator does not reimplement the runtime — it **carries a specific runtime version inside**. Every release therefore states which one (for example, simulator `0.1.0` — runtime `0.9.2`), and the first line of `읽어보세요.txt` in the zip says the same. As with the Raspberry Pi, **a deploy is refused if the editor is newer than the runtime it carries.**

## Requirements

| | Requirement |
|---|---|
| Editor PC | Windows 10/11 x64. Install the [.NET 9 SDK](https://dotnet.microsoft.com/download/dotnet/9.0) yourself — the build runs `dotnet build`, and the setup only installs the desktop runtime |
| Runtime device | Raspberry Pi with Raspberry Pi OS 64-bit (verified; 32-bit untested). .NET 9 is installed by the runtime install script. Same network as the editor (ports 5557/5555, mDNS) |
| Simulator | Windows 10/11 x64. Runs with no separate install (.NET included). Uses the same ports as the runtime (5557/5555, mDNS) |

## Editor install (Windows)

1. Download `Senbrix-win-Setup.exe` from the [latest release](https://github.com/going-kr/Release.Senbrix/releases/latest) and run it.
2. The installer isn't code-signed, so Windows SmartScreen may warn. Choose "More info", then "Run anyway".
3. If the .NET 9 Desktop Runtime is missing, the installer downloads and installs it for you. A one-time admin prompt may appear.
4. The app installs per-user under `%LocalAppData%\Senbrix`; no admin rights required.
5. If the .NET 9 SDK is missing, install the x64 SDK from [here](https://dotnet.microsoft.com/download/dotnet/9.0). The build runs `dotnet build`, so without the SDK, Build fails (editing and saving still work). Check with `dotnet --list-sdks`.

## Runtime install (Raspberry Pi)

Install the Senbrix Runtime — the target the editor deploys to — once on the Raspberry Pi. One line in the Pi's shell (Raspberry Pi OS 64-bit verified; 32-bit untested):

```bash
curl -sSL https://raw.githubusercontent.com/going-kr/Release.Senbrix/master/install-runtime.sh | sudo bash
```

What the script does:
1. Installs the .NET 9 ASP.NET Core runtime to `/opt/dotnet` (using the official `dotnet-install.sh`; arm64/arm32 detected automatically, skipped if already present).
2. Downloads `Senbrix-runtime-x.y.z-linux.tar.gz` from the runtime release (tag `runtime-vX.Y.Z`, separate from the editor release `vX.Y.Z`) and installs it to `/opt/senbrix`. On reinstall or update, `Apps/`, `Logs/` and `appsettings.json` are preserved.
3. Asks whether you use a CAN IO expansion board. Enter the interface name (e.g. `can0`) if you do, or just press Enter if you don't (on reinstall, Enter keeps the current setting).
4. Creates the dedicated user `senbrix` (gpio and dialout groups), registers and starts the systemd service `senbrix-runtime`, and prints its status and IP.

Options: `sudo bash -s -- --version 0.9.0` (pin a version; use the same version as the editor) · `--tarball ./file.tar.gz` (offline, using a pre-downloaded file) · `--can-port <name|none>` (skip the CAN question) · `--no-dotnet` (skip the .NET install).
To update the runtime, run the same command again. To uninstall: `sudo systemctl disable --now senbrix-runtime && sudo rm -rf /opt/senbrix /etc/systemd/system/senbrix-runtime.service`

After the install:
- Network: put the Pi on the same network as the editor PC. If a firewall is active, open 5557 (HTTP), 5555 (TextComm) and 5353/UDP (mDNS).
- Verify: click the connection icon at the bottom of the editor. If the Pi's hostname shows up in the Connect Device list, you're set (enter the IP manually if it doesn't). Deploy then sends the build output and the runtime starts the app immediately.
- Logs are at `journalctl -u senbrix-runtime -f`, settings at `/opt/senbrix/appsettings.json`. `Runtime:CanPort` (for CAN IO expansion boards) is set by the install-time question; to change it later, edit this file and restart the service.
- If the editor is newer than the runtime, deploy is rejected and the status bar says a runtime update is required. Run the command above to update.
- The runtime API is currently unauthenticated. Operate it only on an isolated equipment network.

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

- Editor: once installed, the app checks for a new version at startup. Download and restart from Help › Check for Updates; there's no need to come back to this page.
- Runtime: run the one-liner from [Runtime install](#runtime-install-raspberry-pi) again on the Pi (`Apps/` and settings are preserved). Deploy is rejected when the editor is newer than the runtime, so after updating the editor, update the runtime too.

## Release assets

| Release | File | Purpose |
|---|---|---|
| `vX.Y.Z` (editor) | `Senbrix-win-Setup.exe` | **The file to download for a first editor install** |
| `vX.Y.Z` (editor) | `Senbrix-x.y.z-full.nupkg`, `*-delta.nupkg`, `RELEASES`, `releases.win.json`, `assets.win.json` | Auto-update packages and metadata, not meant for manual download |
| `runtime-vX.Y.Z` (runtime) | `Senbrix-runtime-x.y.z-linux.tar.gz` | The Raspberry Pi runtime. `install-runtime.sh` downloads it itself, so you normally don't download it by hand (offline: `--tarball`) |
| `sim-vX.Y.Z` (simulator) | `Senbrix-sim-x.y.z-win.zip` | For trying things without hardware. Unzip and run `SenbrixSim.exe`. The runtime version it carries is in the release notes and in `읽어보세요.txt` |
| repository root | `install-runtime.sh` | Runtime install script ([Runtime install](#runtime-install-raspberry-pi)) |
| (automatic) | `Source code (zip)`, `Source code (tar.gz)` | GitHub's automatic snapshot of this distribution repository. Not the Senbrix source code; no need to download |

## Feedback

Please file bugs and requests in this repository's [Issues](https://github.com/going-kr/Release.Senbrix/issues).

---

© Going. All rights reserved. Binaries are provided as-is. See [NOTICE.md](NOTICE.md).
