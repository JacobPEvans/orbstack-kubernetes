#!/usr/bin/env bash
# linuxserver.io custom-cont-init hook: install OpenWebStart on first container
# boot and seed an iDRAC bookmark via Firefox enterprise policies. Idempotent
# via "is javaws already on PATH?" — guarantees correctness when the named
# /config volume persists across `docker compose down/up` but the writable
# container layer (where apt installs live) does not.
set -euo pipefail

if command -v javaws >/dev/null 2>&1; then
  echo "[idrac-webtop] OpenWebStart already installed in this container, skipping init."
  exit 0
fi

: "${IDRAC_URL:?IDRAC_URL must be set in the container environment}"

echo "[idrac-webtop] Installing OpenWebStart, Firefox, JRE 8, and ipmitool..."

export DEBIAN_FRONTEND=noninteractive
apt-get update
# openjdk-8-jre is required by OpenWebStart's install4j launcher (it refuses
# to start without a JRE 1.8). The .deb does NOT bundle a JRE.
# openjdk-8-jdk-headless adds jarsigner (the JRE only ships keytool), needed
# by idrac-launch to re-sign Dell's unsigned AVCT KVM jars so IcedTea-Web's
# SecurityDelegateImpl will load them.
# ipmitool gives a CLI fallback (power on/off, sensor reads, sel list) for
# when the JNLP viewer is overkill.
# zip is used by idrac-launch to strip stale signature blocks before re-signing.
# desktop-file-utils + xdg-utils provide update-desktop-database and xdg-mime,
# used below to register idrac-launch as the .jnlp MIME handler. The
# linuxserver/webtop base image does not install them by default.
apt-get install -y --no-install-recommends curl ca-certificates jq firefox openjdk-8-jre openjdk-8-jdk-headless ipmitool zip desktop-file-utils xdg-utils

DEB_URL=$(curl -fsSL https://api.github.com/repos/karakun/OpenWebStart/releases/latest \
  | jq -r '.assets[] | select(.name | test("linux.*\\.deb$")) | .browser_download_url' \
  | head -n1)

if [[ -z "$DEB_URL" ]]; then
  echo "[idrac-webtop] ERROR: could not resolve OpenWebStart .deb asset URL" >&2
  exit 1
fi

echo "[idrac-webtop] Downloading $DEB_URL"
curl -fsSL -o /tmp/openwebstart.deb "$DEB_URL"
apt-get install -y /tmp/openwebstart.deb
rm -f /tmp/openwebstart.deb

# Tell the install4j launcher where to find the JRE 8. /etc/environment is
# read by PAM and inherited by all sessions (terminal and GUI), so Firefox-
# launched .jnlp handlers see it too. The arch suffix tracks dpkg so the path
# is right on both amd64 hosts and arm64 hosts running this container under
# Rosetta (Debian's openjdk-8-jre uses /usr/lib/jvm/java-8-openjdk-<dpkg-arch>).
JAVA8_HOME="/usr/lib/jvm/java-8-openjdk-$(dpkg --print-architecture)"
if ! grep -q '^INSTALL4J_JAVA_HOME=' /etc/environment 2>/dev/null; then
  printf 'INSTALL4J_JAVA_HOME=%s\n' "$JAVA8_HOME" | tee -a /etc/environment >/dev/null
fi

# Install the idrac-launch wrapper and its desktop entry. The .desktop file
# plus update-desktop-database + xdg-mime make double-clicked .jnlp files (and
# Firefox's "open with" path) route through the wrapper instead of straight
# into javaws.
install -m 0755 /opt/idrac-payload/idrac-launch.sh /usr/local/bin/idrac-launch
install -m 0644 /opt/idrac-payload/idrac-launch.desktop /usr/share/applications/idrac-launch.desktop
update-desktop-database /usr/share/applications
xdg-mime default idrac-launch.desktop application/x-java-jnlp-file

# Pre-create the runtime state dir under abc ownership. If a root-owned
# invocation ever races ahead of the first abc-owned one (e.g. someone runs
# `docker exec idrac-webtop /usr/local/bin/idrac-launch ...` without `-u abc`),
# subsequent abc-owned mkdir calls into /config/idrac-viewer/ fail with
# "Permission denied". Pre-creating here eliminates the race and any stale
# root-owned state from a prior container start.
install -d -o abc -g abc /config/idrac-viewer /config/idrac-viewer/cache
if [[ -d /config/idrac-viewer ]]; then
  chown -R abc:abc /config/idrac-viewer
fi

# Seed the iDRAC bookmark + homepage via Firefox enterprise policies, and
# wire Firefox's MIME handler so clicks on "Launch Virtual Console" pipe the
# downloaded JNLP straight into idrac-launch (no Downloads/ detour, no prompt).
# policies.json is profile-independent and applied on every Firefox start.
mkdir -p /usr/lib/firefox/distribution
cat >/usr/lib/firefox/distribution/policies.json <<JSON
{
  "policies": {
    "Bookmarks": [
      {
        "Title": "iDRAC (R410)",
        "URL": "${IDRAC_URL}",
        "Placement": "toolbar"
      }
    ],
    "Homepage": {
      "URL": "${IDRAC_URL}",
      "Locked": false
    },
    "Handlers": {
      "mimeTypes": {
        "application/x-java-jnlp-file": {
          "action": "useHelperApp",
          "ask": false,
          "handlers": [
            {
              "name": "iDRAC Launcher",
              "path": "/usr/local/bin/idrac-launch"
            }
          ]
        }
      }
    }
  }
}
JSON

echo "[idrac-webtop] Init complete. Open http://localhost:3000 — iDRAC is the homepage and a toolbar bookmark; clicking 'Launch Virtual Console' pipes through /usr/local/bin/idrac-launch."
