# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32
# PrusaSlicer for Unraid on LinuxServer.io's baseimage-selkies, streamed to the
# browser.
#
# PrusaSlicer publishes no Linux AppImage on GitHub, so it comes from apt rather
# than the AppImage route LSIO's orcaslicer takes. The base is Debian trixie,
# which carries prusa-slicer in main for amd64 and arm64 and brings its security
# updates along.

ARG BASE_TAG=debiantrixie@sha256:5b448b9d62b6f471ba96104bdf2daedef3ed6852fdea6a780d341b4447a7a68d
FROM ghcr.io/linuxserver/baseimage-selkies:${BASE_TAG}

LABEL maintainer="junkerderprovinz"
LABEL org.opencontainers.image.title="prusaslicer"
LABEL org.opencontainers.image.description="PrusaSlicer for Unraid with a Selkies web desktop: the 3D-printing slicer in your browser, no VNC client"
LABEL org.opencontainers.image.source="https://github.com/junkerderprovinz/prusaslicer"
LABEL org.opencontainers.image.licenses="AGPL-3.0-only"
LABEL org.opencontainers.image.vendor="junkerderprovinz"

# TITLE feeds the PWA manifest; SELKIES_UI_TITLE is the visible tab/sidebar
# title of the Selkies web client. Selkies will not start with basic auth on and
# no password, so SELKIES_ENABLE_BASIC_AUTH=false keeps the no-login default;
# the base's nginx still enforces HTTP basic auth once a real
# CUSTOM_USER/PASSWORD is set.
#
# RESTART_APP=true turns on the base image's svc-watchdog, which runs the
# openbox autostart again when the app disappears; otherwise closing PrusaSlicer
# leaves an empty desktop until the container restarts. The watchdog matches the
# autostart command line, which is why rootfs/defaults/autostart does not `exec`
# the launch.
ENV TITLE="PrusaSlicer" \
    SELKIES_UI_TITLE="PrusaSlicer" \
    SELKIES_ENABLE_BASIC_AUTH="false" \
    RESTART_APP="true"

# wxWidgets grows its text with the DPI Selkies hands a HiDPI browser but keeps
# the layout it measured at 96 DPI, so a laptop streaming in physical pixels
# gets clipped labels and buttons, and panels widened at that DPI stay wide on
# a 100 % display afterwards. Streaming every browser at its CSS size with the
# DPI fixed at 96 keeps one consistent size on any display. HiDPI can still be
# switched on per browser in the Selkies sidebar.
ENV SELKIES_USE_CSS_SCALING="true" \
    SELKIES_SCALING_DPI="96"

# prusa-slicer pulls in its own wxWidgets and GTK3 chain. On top of that: mesa
# DRI so the 3D plater renders through llvmpipe without a GPU, GLU for the 3D
# view, dbus-x11 for the autostart's dbus-launch, gnome-themes-extra for
# Adwaita-dark on the native dialogs, and fonts, since missing ones show as
# blank boxes.
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

COPY rootfs/ /

# rootfs/ ships svc-xorg/dependencies.d/init-dpi so the DPI is settled before
# Xvfb starts. If a base bump renamed svc-xorg, the COPY above would
# create it as a service directory without a `type` file, s6-rc-compile would
# abort and every container would exit at boot while the build stayed green.
# Checking for the base's own `type` file makes that a build error.
RUN set -eux; \
    t=/etc/s6-overlay/s6-rc.d/svc-xorg/type; \
    [ -f "$t" ] || { echo "ERROR: $t missing, the selkies base renamed or dropped svc-xorg; re-point rootfs/etc/s6-overlay/s6-rc.d/svc-xorg/dependencies.d/init-dpi at the new service"; exit 1; }; \
    echo "prusaslicer: dpi oneshot ordered before svc-xorg"

# CR is stripped so a Windows checkout cannot break the banner. The base's own
# adduser branding is blanked so the log shows only the print-banner.sh block.
COPY .github/assets/banner-raw.txt /usr/local/share/banner-raw.txt
RUN tr -d '\r' < /usr/local/share/banner-raw.txt > /usr/local/share/banner.txt; \
    rm -f /usr/local/share/banner-raw.txt; \
    : > /etc/s6-overlay/s6-rc.d/init-adduser/branding 2>/dev/null || true

# Tab and sidebar icon of the Selkies web client.
COPY .github/assets/icon.png /usr/share/selkies/www/icon.png

RUN chmod +x /usr/local/bin/print-banner.sh \
             /etc/s6-overlay/s6-rc.d/init-dpi/run \
             /etc/s6-overlay/s6-rc.d/init-prusaslicer/run \
             /etc/s6-overlay/s6-rc.d/svc-prusaslicer-ready/run \
             /defaults/autostart \
             /defaults/startwm.sh

EXPOSE 3001
VOLUME /config
