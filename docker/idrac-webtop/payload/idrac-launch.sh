#!/usr/bin/env bash
# idrac-launch: self-signs the AVCT KVM jars referenced by an iDRAC 6 viewer
# JNLP and launches the rewritten JNLP through OpenWebStart. Works around the
# hard-coded SecurityDelegateImpl.getClassLoaderSecurity check in IcedTea-Web
# that rejects unsigned jars with <all-permissions/>.
#
# Usage: idrac-launch <path-to-viewer.jnlp>
#
# The signed jar cache lives at /config/idrac-viewer/cache/<host>_<port>/ and
# survives `docker compose down/up`. The self-signed keystore lives at
# /config/idrac-viewer/keystore.jks. Both are isolated to this container; the
# keystore is never exported or trusted elsewhere.
set -euo pipefail

JNLP_IN="${1:?usage: idrac-launch <path-to-viewer.jnlp>}"
[[ -r "$JNLP_IN" ]] || { echo "idrac-launch: cannot read $JNLP_IN" >&2; exit 2; }

ROOT=/config/idrac-viewer
KEYSTORE="$ROOT/keystore.jks"
STOREPASS=changeit
ALIAS=idrac-launch

mkdir -p "$ROOT/cache"

# Parse codebase + jar/nativelib hrefs out of the JNLP. The iDRAC 6 JNLP shape
# is single-line attributes, no XML namespaces, no CDATA — grep is enough.
CODEBASE=$(grep -oE 'codebase="[^"]+"' "$JNLP_IN" | head -n1 | sed -E 's/^codebase="(.*)"$/\1/')
if [[ -z "$CODEBASE" ]]; then
  echo "idrac-launch: no codebase= attribute in $JNLP_IN" >&2
  exit 3
fi

# Pull host and port (default to 443 for https).
HOST_PORT=$(echo "$CODEBASE" | sed -E 's#^https?://##; s#/$##')
HOST="${HOST_PORT%%:*}"
PORT="${HOST_PORT##*:}"
[[ "$PORT" == "$HOST" ]] && PORT=443

CACHE_DIR="$ROOT/cache/${HOST}_${PORT}"
SENTINEL="$CACHE_DIR/.signed"

# Generate keystore once. Long validity, RSA-2048, name doesn't matter — the
# iDRAC viewer never checks who signed.
if [[ ! -s "$KEYSTORE" ]]; then
  echo "[idrac-launch] generating self-signed keystore at $KEYSTORE"
  keytool -genkeypair \
    -keystore "$KEYSTORE" -storepass "$STOREPASS" -keypass "$STOREPASS" \
    -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 36500 \
    -dname "CN=idrac-launch, OU=local, O=local, L=local, S=local, C=US" \
    -storetype JKS
fi

# Curl args that talk to iDRAC 6's antique TLS stack. SECLEVEL=0 lets OpenSSL
# negotiate the legacy ciphers the BMC offers; -k skips the self-signed cert
# check because we explicitly trust this LAN endpoint.
CURL_ARGS=(-fsSL -k --tlsv1 --tls-max 1.2 --ciphers DEFAULT@SECLEVEL=0)

if [[ ! -f "$SENTINEL" ]]; then
  echo "[idrac-launch] cold cache for ${HOST}:${PORT} — downloading and signing jars"
  mkdir -p "$CACHE_DIR"

  # Extract every jar/nativelib href. Each line: full URL.
  HREFS=$(grep -oE '(jar|nativelib) +href="[^"]+"' "$JNLP_IN" \
    | sed -E 's/^(jar|nativelib) +href="(.*)"$/\2/' | sort -u)

  if [[ -z "$HREFS" ]]; then
    echo "idrac-launch: no <jar>/<nativelib> entries in $JNLP_IN" >&2
    exit 4
  fi

  while IFS= read -r URL; do
    BASE=$(basename "$URL")
    OUT="$CACHE_DIR/$BASE"
    echo "  download $URL"
    curl "${CURL_ARGS[@]}" -o "$OUT" "$URL"

    # Strip any pre-existing signature blocks so jarsigner re-signs cleanly.
    # iDRAC 6 jars are unsigned, but be defensive: future firmware could ship
    # stale/expired signatures that would conflict with ours.
    zip --quiet -d "$OUT" 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.DSA' 'META-INF/*.EC' 2>/dev/null || true

    echo "  sign     $BASE"
    jarsigner -keystore "$KEYSTORE" -storepass "$STOREPASS" \
      -sigalg SHA256withRSA -digestalg SHA-256 \
      "$OUT" "$ALIAS" >/dev/null
  done <<< "$HREFS"

  touch "$SENTINEL"
  echo "[idrac-launch] cache populated at $CACHE_DIR"
fi

# Rewrite the JNLP: point codebase at the local cache, shorten each jar href
# to the bare filename, and drop decorative <icon>/<shortcut> tags that point
# at the iDRAC's HTTPS endpoint (its self-signed cert fails ITW's trust
# manager and produces alarming-looking stack traces even though the icon is
# just a splash screen). All <argument> session tokens are preserved verbatim.
REWRITTEN=$(mktemp --suffix=.jnlp)
trap 'rm -f "$REWRITTEN"' EXIT

ESCAPED_CODEBASE=$(printf '%s' "$CODEBASE" | sed -E 's#[]\[\\/.^$*]#\\&#g')
sed -E \
  -e "s#codebase=\"$ESCAPED_CODEBASE\"#codebase=\"file://$CACHE_DIR\"#" \
  -e 's#href="https?://[^"]*/([^/"]+\.jar)"#href="\1"#g' \
  -e '/<icon[^>]*\/>/d' \
  -e '/<shortcut[^>]*\/>/d' \
  -e '/<shortcut[^>]*>/,/<\/shortcut>/d' \
  "$JNLP_IN" > "$REWRITTEN"

echo "[idrac-launch] launching $REWRITTEN"
exec javaws "$REWRITTEN"
