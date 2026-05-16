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

Tear down:

```sh
docker compose down       # keep volume (faster next boot)
docker compose down -v    # nuke everything (re-runs OpenWebStart install)
```

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
- **Init hook:** `init/10-install-openwebstart.sh` is bind-mounted into the linuxserver.io `/custom-cont-init.d/` hook directory and runs as root on every container start. Idempotent via `/config/.openwebstart-installed` sentinel.
  - **First boot:** apt-update, install Firefox + `openjdk-8-jre` (required by OpenWebStart's install4j launcher), resolve the latest OpenWebStart `.deb` from `karakun/OpenWebStart` GitHub releases, install it, write `INSTALL4J_JAVA_HOME` to `/etc/environment` so the GUI session and Firefox-launched `.jnlp` handlers find the JRE, seed a Firefox bookmark pointing at `${IDRAC_URL}`, write sentinel.
  - **Subsequent boots:** sentinel exists, script exits immediately.
  - Force re-install: `docker compose down -v` to drop the volume.
- **Persistence:** named volume `idrac-webtop-config` for `/config` (Firefox profile, installed packages, bookmark).
- **Config:** `IDRAC_URL` required in `.env` (gitignored). `.env.example` is checked in with a scrubbed placeholder.

Security posture (mirrors `../actions-runner/docker-compose.yml`):

- No `docker.sock` mount, no host networking, no privileged mode.
- Port 3000 binds to all interfaces by default. If your Mac is on an untrusted network, change `"3000:3000"` to `"127.0.0.1:3000:3000"` in `docker-compose.yml`.
- `.env` (containing the real iDRAC IP) is gitignored.
