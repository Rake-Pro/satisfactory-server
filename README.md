# satisfactory-server

Satisfactory dedicated server (SteamCMD-based, with `ficsit-cli` for headless
mod install/update from ficsit.app).

```
ghcr.io/rake-pro/satisfactory-server
```

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
| `STEAMBETA` / `STEAMBETAID` | `false` / (empty) | Opt into a Steam beta branch. |
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
