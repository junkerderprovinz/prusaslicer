#!/usr/bin/env bash
# Overrides the Selkies base image's /defaults/startwm.sh and matches it. The
# session goes to /dev/null like in the base script: it prints continuously,
# and the "<APP> IS READY" banner from svc-prusaslicer-ready has to stay the
# last block in `docker logs`. Lift the redirect only while debugging the
# desktop.

exec dbus-launch --exit-with-session /usr/bin/openbox-session > /dev/null 2>&1
