#!/usr/bin/env bash
# linuxserver.io custom-cont-init hook: install OpenWebStart and seed a Firefox
# bookmark for the iDRAC URL on first container boot. Idempotent via sentinel.
set -euo pipefail

SENTINEL=/config/.openwebstart-installed
if [[ -f "$SENTINEL" ]]; then
  echo "[idrac-webtop] OpenWebStart already installed, skipping init."
  exit 0
fi

: "${IDRAC_URL:?IDRAC_URL must be set in the container environment}"

echo "[idrac-webtop] Installing OpenWebStart and Firefox..."

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
# launched .jnlp handlers see it too. Arch-suffix on the path is correct for
# both arm64 (Apple Silicon) and amd64 hosts because Debian's openjdk-8-jre
# uses /usr/lib/jvm/java-8-openjdk-<dpkg-arch>.
JAVA8_HOME="/usr/lib/jvm/java-8-openjdk-$(dpkg --print-architecture)"
if ! grep -q '^INSTALL4J_JAVA_HOME=' /etc/environment 2>/dev/null; then
  printf 'INSTALL4J_JAVA_HOME=%s\n' "$JAVA8_HOME" | tee -a /etc/environment >/dev/null
fi

# Seed a Firefox bookmark for the iDRAC URL. Writing to bookmarks.html in the
# default profile dir works on first profile creation; if Firefox has already
# created a profile, drop the file under it. The directory pattern is
# /config/.mozilla/firefox/<random>.default* — glob to find it (or create one
# under a known name so the bookmark is always available).
PROFILE_PARENT=/config/.mozilla/firefox
mkdir -p "$PROFILE_PARENT"
PROFILE_DIR=$(find "$PROFILE_PARENT" -maxdepth 1 -type d -name '*.default*' | head -n1 || true)
if [[ -z "$PROFILE_DIR" ]]; then
  PROFILE_DIR="$PROFILE_PARENT/idrac.default"
  mkdir -p "$PROFILE_DIR"
fi

cat >"$PROFILE_DIR/bookmarks.html" <<HTML
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Menu</H1>
<DL><p>
  <DT><A HREF="${IDRAC_URL}">iDRAC (R410)</A>
</DL><p>
HTML

# Ensure the profile is readable by the desktop user (PUID/PGID from compose).
chown -R "${PUID:-1000}:${PGID:-1000}" "$PROFILE_PARENT"

touch "$SENTINEL"
chown "${PUID:-1000}:${PGID:-1000}" "$SENTINEL"

echo "[idrac-webtop] Init complete. Open http://localhost:3000 and click the iDRAC bookmark."
