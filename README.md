<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/junkerderprovinz/prusaslicer/main/.github/assets/prusaslicer-banner-dark.png">
    <img src="https://raw.githubusercontent.com/junkerderprovinz/prusaslicer/main/.github/assets/prusaslicer-banner.png" alt="PrusaSlicer — have your model and slice it too" width="100%">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/junkerderprovinz/prusaslicer/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/junkerderprovinz/prusaslicer/build.yml?branch=main&label=Build&style=for-the-badge&logo=githubactions&logoColor=white" alt="Build" height="36"></a>&nbsp;
  <a href="https://github.com/junkerderprovinz/prusaslicer/actions/workflows/lint.yml"><img src="https://img.shields.io/github/actions/workflow/status/junkerderprovinz/prusaslicer/lint.yml?branch=main&label=Lint&style=for-the-badge&logo=githubactions&logoColor=white" alt="Lint" height="36"></a>&nbsp;
  <a href="https://hub.docker.com/r/junkerderprovinz/prusaslicer"><img src="https://img.shields.io/docker/pulls/junkerderprovinz/prusaslicer?style=for-the-badge&logo=docker&logoColor=white&label=Pulls&color=1d99f3" alt="Docker Pulls" height="36"></a>&nbsp;
  <a href="https://hub.docker.com/r/junkerderprovinz/prusaslicer"><img src="https://img.shields.io/docker/image-size/junkerderprovinz/prusaslicer/latest?style=for-the-badge&logo=docker&logoColor=white&label=Size&color=1d99f3" alt="Image Size" height="36"></a>&nbsp;
  <a href="https://github.com/junkerderprovinz/prusaslicer/pkgs/container/prusaslicer"><img src="https://img.shields.io/badge/Arch-amd64%20%7C%20arm64-success?style=for-the-badge&logo=linux&logoColor=white" alt="Arch" height="36"></a>&nbsp;
  <a href="https://github.com/prusa3d/PrusaSlicer"><img src="https://img.shields.io/badge/Engine-PrusaSlicer-0d9488?style=for-the-badge&logoColor=white" alt="PrusaSlicer" height="36"></a>&nbsp;
  <a href="https://unraid.net"><img src="https://img.shields.io/badge/Unraid-Template-f15a2c?style=for-the-badge&logo=unraid&logoColor=white" alt="Unraid" height="36"></a>&nbsp;
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge&logo=opensourceinitiative&logoColor=white" alt="License" height="36"></a>
</p>

<p align="center">
<b>PrusaSlicer, in your browser.</b> Slice from any device — no VNC client, no local install.<br>
This runs the full PrusaSlicer desktop app inside a single container and streams it to your
browser over <a href="https://github.com/selkies-project/selkies">Selkies</a> (WebRTC), so the
3D plate stays smooth to rotate, zoom and drag — the part of slicing where the old noVNC
containers feel laggy.
</p>

<p align="center">
  <a href="https://buymeacoffee.com/junkerderprovinz">
    <img src="https://raw.githubusercontent.com/junkerderprovinz/prusaslicer/main/.github/assets/button-buy-me-a-coffee.svg" alt="Buy me a coffee" width="220">
  </a>
</p>

<br>

## Table of Contents

1. [What is this?](#1-what-is-this)
2. [Why Selkies?](#2-why-selkies)
3. [Install on Unraid](#3-install-on-unraid)
4. [Configuration](#4-configuration)
5. [First use](#5-first-use)
6. [How it works](#6-how-it-works)
7. [Credits](#7-credits)

<br>

## 1. What is this?

An **own-image container** that packages [**PrusaSlicer**](https://github.com/prusa3d/PrusaSlicer) —
the FDM/SLA slicer from Prusa Research — on top of
[**LinuxServer.io's baseimage-selkies**](https://github.com/linuxserver/docker-baseimage-selkies)
and serves its desktop UI straight to your browser. No X client, no VNC viewer, no separate
install on your workstation: open the WebUI and slice.

LinuxServer ship OrcaSlicer and Cura on Selkies, but **not PrusaSlicer**, and the only other
browser-based PrusaSlicer images are years-old, abandoned noVNC builds. This is a maintained,
modern **Selkies (WebRTC)** build for **amd64 and arm64**.

PrusaSlicer itself is installed from **Debian trixie's `prusa-slicer` package** (PrusaSlicer no
longer ships a Linux AppImage), so it tracks Debian's security updates and works natively on
both architectures.

<br>

## 2. Why Selkies?

Slicing is a 3D-viewport workflow: you rotate the plate, zoom into overhangs, drag and orient
models, and scrub the layer/tool-path preview. Over the older **noVNC** stack that continuous
canvas feels laggy because the whole frame is re-encoded on every change. **Selkies streams the
desktop over WebRTC**, the same reason LinuxServer moved Orca, Cura, Blender and FreeCAD onto it —
so the plate stays responsive. When the host has a GPU the base wires it through; without one it
falls back to software rendering so it still works.

<br>

## 3. Install on Unraid

Requires **Unraid 6.12+**. Install via **Community Applications** — search for **PrusaSlicer**
(look for the `junkerderprovinz` maintainer). Or add the template repository manually under
**Docker → Add Container → Template repositories**:

```
https://github.com/junkerderprovinz/unraid-apps
```

Then open the WebUI on the mapped **HTTPS** port (default `3001`).

<br>

## 4. Configuration

| Variable | Required | Description |
|---|---|---|
| `CUSTOM_USER` | No | WebUI login user. Leave empty (with `PASSWORD`) for **no login** on a trusted LAN. |
| `PASSWORD` | No | WebUI login password. Empty = no login; set both to enable HTTP basic auth on the WebUI. |
| `CUSTOM_HTTPS_PORT` | No | HTTPS port the WebUI is served on (default `3001`). |
| `PUID` / `PGID` | No | User/group the app runs as, so files it writes match your share ownership. The Unraid template sets `99`/`100` (nobody/users). |
| `TZ` | No | Timezone (e.g. `Europe/Berlin`). |

Mount your models/projects folder to a path inside the container (e.g. `/config/projects` or a
dedicated `/models` mapping) so slices and G-code land on your array. PrusaSlicer's own
configuration (printer/filament/print profiles) persists under **`/config`**.

> [!NOTE]
> The WebUI has **no login by default** for trusted-LAN use. Never expose it directly to the
> internet — put it behind a VPN or a reverse proxy that adds authentication, or set
> `CUSTOM_USER` + `PASSWORD` to enable the built-in basic auth.

<br>

## 5. First use

1. Open the WebUI — PrusaSlicer starts maximised, ready to slice.
2. Run the **Configuration Assistant** (first launch) and pick your printer(s) and filament(s).
3. Import a model (`File → Import`, or drag it onto the plate from your mounted folder), slice,
   and export the G-code to your mounted output folder.
4. Prefer a dark UI? PrusaSlicer has its own **Dark mode** under *Preferences → General → Dark
   mode*; the container's GTK chrome is already dark.

Closing the PrusaSlicer window simply reopens a fresh instance — it is the container's single
app (kiosk model), so there is nothing else to manage.

<br>

## 6. How it works

```
Browser ──WebRTC (Selkies)──> PrusaSlicer container
                              ├─ nginx (Selkies WebUI, HTTPS :3001)
                              ├─ openbox + Selkies desktop
                              └─ /usr/bin/prusa-slicer  (Debian trixie package)
                                 └─ /config  (printer/filament/print profiles, persisted)
```

Built on `ghcr.io/linuxserver/baseimage-selkies:debiantrixie`. A small s6 overlay seeds the
openbox autostart (which launches PrusaSlicer as the session's single app), keeps the WebUI
login-free unless you set credentials, and prints a **`PRUSASLICER IS READY`** banner to the
container log once the WebUI is serving. Images are built natively per architecture, boot-smoke
tested (the binary is present **and** the WebUI answers) before publishing, and scanned for CVEs.

<br>

## 7. Credits

- **[PrusaSlicer](https://github.com/prusa3d/PrusaSlicer)** by Prusa Research (AGPL-3.0) — the
  slicer this image packages. Installed from the Debian `prusa-slicer` package. This project is
  **not affiliated with or endorsed by Prusa Research**.
- **[LinuxServer.io baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies)**
  (GPL-3.0) — the Selkies web-desktop base.
- **[Selkies](https://github.com/selkies-project/selkies)** — the WebRTC desktop streaming stack.

See [`NOTICE`](NOTICE) for the full bundled-software license list. This repository's own wrapper
(Dockerfile, rootfs, scripts, artwork) is MIT — see [`LICENSE`](LICENSE).

<br>

<p align="center">
  If this saved you a slicer setup, consider buying me a coffee:<br><br>
  <a href="https://buymeacoffee.com/junkerderprovinz">
    <img src="https://raw.githubusercontent.com/junkerderprovinz/prusaslicer/main/.github/assets/button-buy-me-a-coffee.svg" alt="Buy me a coffee" width="220">
  </a>
</p>

---

<sub>Part of a family of self-hosted Unraid apps + plugins by <b>junkerderprovinz</b> — see them all at <a href="https://github.com/junkerderprovinz">github.com/junkerderprovinz</a>, or install from <a href="https://unraid.net/community/apps">Community Applications</a>.</sub>
