# satisfactory-server

Satisfactory dedicated server (SteamCMD-based, with `ficsit-cli` for headless
mod install/update from ficsit.app).

```
ghcr.io/rake-pro/satisfactory-server
```

## Base image

Built `FROM ghcr.io/rake-pro/steamcmd-base:latest`.

| Item | Value |
| --- | --- |
| SteamCMD | `/home/steam/steamcmd/steamcmd.sh` (installed and self-updated in the base image). |
| Steam user | `steam`, UID/GID `1000` by default, home `/home/steam`. |
| Shared helpers | `/opt/scripts/functions.sh` (`Log*`, `require_env`, `steamcmd_update`, `remap_steam_user`), sourced by `scripts/functions.sh`. |
| Runtime user | The container boots as `root` so `init.sh` can remap `steam` to `PUID`/`PGID`; ficsit-cli and the server itself run as `steam` via `gosu`. |
| Packages | `gosu`, `curl`, `ca-certificates`, `procps` and the 32-bit SteamCMD runtime come from the base; this image apt-installs nothing. |

## Tags / releases

| Tag | Meaning |
| --- | --- |
| `X.Y.Z` | Immutable release, built from git tag `vX.Y.Z` |
| `X.Y` | Latest patch of that minor |
| `latest` | Latest release |
| `sha-<short>` | Commit the image was built from |

- `dev` is the integration branch (default); `ci.yml` builds on every push and PR
  and publishes `:dev` / `:dev-<sha>` images on pushes to `dev`.
- `sync-main.yml` opens a promotion PR from `dev` to `main`. Merging it (merge
  commit) mints the next patch tag and `release.yml` builds, pushes and
  Trivy-scans the image (blocking on fixable CRITICALs).
- Label the promotion PR `release:minor` or `release:major` to change the bump.
- Pin `X.Y.Z` in deployments; `latest` is a convenience pointer.

## Run

```
docker run -d --name satisfactory \
  -p 7777:7777/tcp -p 7777:7777/udp -p 8888:8888/tcp \
  -e MAXPLAYERS=4 \
  -e PUID=1000 -e PGID=1000 \
  -v /path/to/data:/satisfactory \
  ghcr.io/rake-pro/satisfactory-server:latest
```

On boot the server installs/updates via SteamCMD (unless `SKIPUPDATE=true`),
applies mods if `MODS` is set, then launches. Saves and config persist under the
`/satisfactory` volume.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `MAXPLAYERS` | `4` | Player cap (applied via launch-time `-ini` override). |
| `SERVER_PORT` | `7777` | Game port (TCP+UDP). |
| `RELIABLE_PORT` | `8888` | Reliable/messaging port (TCP). |
| `MODS` | (empty) | Space-separated ficsit mod refs, each optionally pinned `ref@version` (default latest). SML + dependencies are pulled automatically. |
| `SKIPUPDATE` | `false` | Skip the SteamCMD update on boot (still installs if missing). |
| `STEAM_BETA` | (empty) | Steam beta branch name (canonical base-image variable, e.g. `experimental`). Empty or `public` = default branch. |
| `STEAMBETA` / `STEAMBETAID` | `false` / (empty) | Legacy beta opt-in, still supported. `STEAMBETA=true` plus `STEAMBETAID=<branch>` sets `STEAM_BETA` internally and takes precedence over `STEAM_BETA`. |
| `STEAM_BETA_PASSWORD` | (empty) | Password for a private beta branch. |
| `STEAMCMD_RETRIES` | `3` | SteamCMD attempts before the final wipe-and-validate pass. |
| `PUID` / `PGID` | `1000` | UID/GID that owns files on the volume (required). |

## Ports

| Port | Use |
| --- | --- |
| `7777/tcp`+`7777/udp` | Game port. |
| `8888/tcp` | Reliable port. |

## Volumes

| Path | Use |
| --- | --- |
| `/satisfactory` | Game install + saves (`/satisfactory/saved`); persist this. |

- Saves live at `$SAVED_DIR` (`/satisfactory/saved`). `init.sh` symlinks
  `/home/steam/.config/Epic/FactoryGame` at it, so worlds survive restarts.

## Update behaviour

- On boot `init.sh` runs SteamCMD unless `SKIPUPDATE=true` (it still installs
  when `FactoryServer.sh` is missing).
- Success is judged by the app manifest (`StateFlags 4`), not by SteamCMD's
  exit code, which is unreliable.
- Failed attempts are retried inside the same container run (`~/Steam` is
  ephemeral, so a restart is always a cold-cache attempt 1). After
  `STEAMCMD_RETRIES` failures the helper wipes `/satisfactory/steamapps` and
  makes one final full-`validate` attempt.
- If every attempt fails the container still boots the existing (possibly
  stale) build and logs `STEAMCMD UPDATE FAILED` in red.
