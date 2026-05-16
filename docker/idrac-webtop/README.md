# idrac-webtop

Browser-accessible XFCE desktop with Firefox + OpenWebStart for reaching the
Dell PowerEdge R410 iDRAC 6 web UI and Java JNLP virtual console.

iDRAC 6 needs legacy TLS ciphers + a Java JNLP runtime that modern macOS
browsers no longer support. Everything legacy lives inside this disposable
container; the Mac host stays clean.

This is a personal dev convenience. It's intentionally not wired into `make`,
CI, or the monitoring kustomize tree.

## Quick Start

```sh
cp .env.example .env
$EDITOR .env                      # set IDRAC_URL=https://<your-idrac-ip>
docker compose up -d
docker compose logs -f webtop     # wait for "Init complete." line (~30-60s first boot)
```

Then open <http://localhost:3000>. XFCE desktop loads in the browser tab.

To reach iDRAC:

1. Launch Firefox inside the webtop desktop.
2. Click the **iDRAC (R410)** bookmark.
3. Accept the self-signed cert.
4. Log in to the iDRAC web UI.
5. **Console → Launch** — the `.jnlp` file opens in OpenWebStart automatically and the KVM window appears inside the desktop.

### CLI fallback: ipmitool

For quick power/sensor/SEL operations without launching the full Java viewer, open a terminal inside the webtop and use `ipmitool` against the iDRAC's IPMI-over-LAN endpoint:

```sh
ipmitool -I lanplus -H <idrac-ip> -U root -P <password> chassis status
ipmitool -I lanplus -H <idrac-ip> -U root -P <password> chassis power on|off|cycle|reset
ipmitool -I lanplus -H <idrac-ip> -U root -P <password> sel list
ipmitool -I lanplus -H <idrac-ip> -U root -P <password> sensor list
```

Tear down:

```sh
docker compose stop       # keep container + volume; `docker compose start` resumes instantly
docker compose down       # remove container; volume persists (Firefox profile/cookies kept)
docker compose down -v    # remove container AND volume; nothing remains
```

Note: `down` removes the container, which discards the writable layer where
`apt`-installed packages live (Firefox, OpenWebStart, JRE 8, ipmitool). The
init hook re-runs and re-installs them on the next `up`. Use `stop`/`start`
instead of `down`/`up` if you want the fastest reuse — the install step is
~30-60s, not free.

## Architecture

Single-service compose stack on the Mac via OrbStack Docker:

```text
Mac browser ──http://localhost:3000──▶ webtop container (XFCE + Firefox + OpenWebStart)
                                                         │
                                                         ├─https──▶ iDRAC 6 web UI (legacy TLS)
                                                         └─jnlp───▶ iDRAC virtual console (Java KVM)
```

Components:

- **Image:** `lscr.io/linuxserver/webtop:ubuntu-xfce` — full XFCE desktop streamed to a browser tab on port 3000.
- **Platform:** pinned to `linux/amd64`. iDRAC 6's `viewer.jnlp` ships only x86_64 native libs and OpenWebStart auto-downloads an x86_64 JRE to satisfy the JNLP request. On Apple Silicon Macs, OrbStack runs the container under Rosetta. On amd64 hosts this is a no-op.
- **Init hook:** `init/10-install-openwebstart.sh` is bind-mounted into the linuxserver.io `/custom-cont-init.d/` directory and runs as root on every container start. Idempotent via `command -v javaws` — the check looks at the container's writable layer (where `apt` installs live), so it correctly re-runs after `docker compose down/up` recreates the container.
  - **Fresh container:** apt-update, install Firefox + `openjdk-8-jre` (required by OpenWebStart's install4j launcher) + `ipmitool`, resolve the latest OpenWebStart `.deb` from `karakun/OpenWebStart` GitHub releases, install it, write `INSTALL4J_JAVA_HOME` to `/etc/environment` so the GUI session and Firefox-launched `.jnlp` handlers find the JRE, write a Firefox `policies.json` setting both the iDRAC homepage and a toolbar bookmark.
  - **Same container restart:** `javaws` is on PATH, script exits immediately.
- **Persistence:** named volume `idrac-webtop-config` for `/config` (Firefox profile, cookies). Apt-installed packages live in the writable container layer and do NOT persist across `down/up`; the init hook reinstalls them on the next start.
- **Config:** `IDRAC_URL` required in `.env` (gitignored). `.env.example` is checked in with a scrubbed placeholder.

Security posture (mirrors `../actions-runner/docker-compose.yml`):

- No `docker.sock` mount, no host networking, no privileged mode.
- Port 3000 binds to `127.0.0.1` only — no LAN exposure of the unauthenticated XFCE session (or of the cached iDRAC login inside it). If you need LAN access, put a reverse proxy with auth in front.
- `.env` (containing the real iDRAC IP) is gitignored.
