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
# ipmitool gives a CLI fallback (power on/off, sensor reads, sel list) for
# when the JNLP viewer is overkill.
apt-get install -y --no-install-recommends curl ca-certificates jq firefox openjdk-8-jre ipmitool

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

# Seed the iDRAC bookmark via Firefox enterprise policies. policies.json is
# profile-independent and applied on every Firefox start, so no profile dir
# detection, no bookmarks.html parsing quirks, no chown on /config/.mozilla.
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
    }
  }
}
JSON

echo "[idrac-webtop] Init complete. Open http://localhost:3000 — iDRAC is the homepage and a toolbar bookmark."
