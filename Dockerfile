# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# PrusaSlicer for Unraid — Selkies web desktop
# ---------------------------------------------------------------------------
# PrusaSlicer packaged on top of LinuxServer.io's baseimage-selkies and streamed
# to the browser via Selkies (WebRTC). LinuxServer ships OrcaSlicer and Cura on
# Selkies but no PrusaSlicer; the only third-party PrusaSlicer web images are
# abandoned noVNC builds. This is a maintained, modern Selkies build.
#
# Why apt instead of an AppImage (as LSIO's orcaslicer does): PrusaSlicer no
# longer publishes a Linux AppImage on GitHub (Windows/macOS only). Debian
# trixie — which this base IS (baseimage-selkies:debiantrixie) — carries
# `prusa-slicer` in main for both amd64 and arm64, so apt is the simplest and
# most robust source and it tracks trixie security updates for free.
#
# Repository:  https://github.com/junkerderprovinz/prusaslicer
# ---------------------------------------------------------------------------

ARG BASE_TAG=debiantrixie
FROM ghcr.io/linuxserver/baseimage-selkies:${BASE_TAG}

LABEL maintainer="junkerderprovinz"
LABEL org.opencontainers.image.title="prusaslicer"
LABEL org.opencontainers.image.description="PrusaSlicer for Unraid with a Selkies web desktop — the 3D-printing slicer in your browser, no VNC client"
LABEL org.opencontainers.image.source="https://github.com/junkerderprovinz/prusaslicer"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"
LABEL org.opencontainers.image.vendor="junkerderprovinz"

# TITLE feeds the PWA manifest; SELKIES_UI_TITLE is the visible tab/sidebar
# title of the Selkies web client. SELKIES_ENABLE_BASIC_AUTH=false keeps the
# no-login-by-default behaviour (see init-nologin); the base's nginx still
# enforces HTTP basic auth once a real CUSTOM_USER/PASSWORD is set.
#
# RESTART_APP=true turns on the base image's svc-watchdog, which runs the
# openbox autostart again whenever the application disappears. Without it,
# closing PrusaSlicer in the browser left an empty black desktop that only a
# container restart could recover, since openbox keeps running on its own. The
# watchdog finds the process by matching the autostart command line, which is
# why rootfs/defaults/autostart must not `exec` the launch (the comment there
# has the details).
#
# NO MAX_RES DEFAULT HERE, ON PURPOSE. The virtual screen is the container's
# biggest single memory item: the X server allocates the whole framebuffer up
# front, about 4 bytes per pixel, so the base default of 15360x8640 is 530 MB
# before anything else runs. The full range has to stay available, so the
# choice belongs to the user: the Unraid template offers a preset dropdown
# (MAX_RES) plus a free field (MAX_RES_CUSTOM) whose value wins, and
# init-screen-size settles the two before svc-xorg reads them.
ENV TITLE="PrusaSlicer" \
    SELKIES_UI_TITLE="PrusaSlicer" \
    SELKIES_ENABLE_BASIC_AUTH="false" \
    RESTART_APP="true"

# ---------------------------------------------------------------------------
# Packages: PrusaSlicer + the GL/GTK/font runtime the headless desktop needs.
# prusa-slicer pulls its own wxWidgets/GTK3 dependency chain; we add:
#   * mesa DRI drivers (libgl1-mesa-dri) so the 3D plater renders via llvmpipe
#     when no GPU is present (the base wires zink/virgl when one is),
#   * libglu1-mesa (GLU, used by the slicer's 3D view),
#   * dbus-x11 for the dbus-launch in the openbox autostart,
#   * gnome-themes-extra for the Adwaita-dark GTK theme (house dark look on the
#     native dialogs; PrusaSlicer has its own in-app dark mode too),
#   * fontconfig + Noto/DejaVu/Liberation so UI text renders (missing fonts
#     show as blank boxes on Qt/GTK), plus locales.
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        prusa-slicer \
        libgl1-mesa-dri libglu1-mesa mesa-utils \
        dbus-x11 \
        gnome-themes-extra adwaita-icon-theme \
        fontconfig \
        fonts-noto fonts-noto-cjk fonts-noto-color-emoji \
        fonts-dejavu fonts-dejavu-core \
        fonts-liberation2 \
        locales coreutils sed; \
    fc-cache -f >/dev/null 2>&1 || true; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Overlay: rootfs (s6 services, openbox autostart, startwm.sh) + init banner.
# ---------------------------------------------------------------------------
COPY rootfs/ /

# ---------------------------------------------------------------------------
# Assert the X service we hook the screen size onto is really the base's
# ---------------------------------------------------------------------------
# rootfs/ ships svc-xorg/dependencies.d/init-screen-size so our oneshot settles
# MAX_RES before Xvfb reads it. If a base bump ever renames that service, the
# COPY above would CREATE /etc/s6-overlay/s6-rc.d/svc-xorg as a service
# directory with a dependency and no `type` file. s6-rc-compile then aborts in
# stage 2 and EVERY container exits at boot, while the build itself stays
# green, so the failure would only show up in users' logs. Checking for the
# base's own `type` file turns that into a build error instead.
RUN set -eux; \
    t=/etc/s6-overlay/s6-rc.d/svc-xorg/type; \
    [ -f "$t" ] || { echo "ERROR: $t missing — the selkies base renamed or dropped svc-xorg; re-point rootfs/etc/s6-overlay/s6-rc.d/svc-xorg/dependencies.d/init-screen-size at the new service"; exit 1; }; \
    echo "prusaslicer: screen-size oneshot ordered before svc-xorg"

# Init-log banner: single source at .github/assets/banner-raw.txt (CR stripped
# so a Windows checkout can't break it). Also blank the base's own adduser
# branding banner so the log shows only our print-banner.sh block.
COPY .github/assets/banner-raw.txt /usr/local/share/banner-raw.txt
RUN tr -d '\r' < /usr/local/share/banner-raw.txt > /usr/local/share/banner.txt; \
    rm -f /usr/local/share/banner-raw.txt; \
    : > /etc/s6-overlay/s6-rc.d/init-adduser/branding 2>/dev/null || true

# CA/PWA icon shown in the Selkies web client tab + sidebar.
COPY .github/assets/icon.png /usr/share/selkies/www/icon.png

RUN chmod +x /usr/local/bin/print-banner.sh \
             /usr/local/bin/selkies-resolution.sh \
             /etc/s6-overlay/s6-rc.d/init-screen-size/run \
             /etc/s6-overlay/s6-rc.d/init-prusaslicer/run \
             /etc/s6-overlay/s6-rc.d/init-nologin/run \
             /etc/s6-overlay/s6-rc.d/svc-prusaslicer-ready/run \
             /defaults/autostart \
             /defaults/startwm.sh

EXPOSE 3001
VOLUME /config
