#!/bin/bash
# shellcheck source=scripts/functions.sh
source "/home/steam/server/functions.sh"

# These directories are PVC-backed. On a fresh deploy or after a wipe they can
# be empty and/or missing.
mkdir -p "$INSTALL_DIR" "$SAVED_DIR"

# Satisfactory writes saves/config under $HOME/.config/Epic/FactoryGame. Point
# that at the persisted volume so worlds survive pod restarts.
mkdir -p /home/steam/.config/Epic
ln -sfn "$SAVED_DIR" /home/steam/.config/Epic/FactoryGame

LogAction "Set file permissions"

# Require PUID/PGID so files on the PVC are owned predictably.
if [ -z "${PUID}" ] || [ -z "${PGID}" ]; then
    LogError "PUID and PGID not set. Please set these in the environment variables."
    exit 1
else
    usermod -o -u "${PUID}" steam
    groupmod -o -g "${PGID}" steam
fi

chown -R steam:steam "$INSTALL_DIR" /home/steam/ || true

# Update on start unless told to skip. Always (re)install if the launch script
# is missing - e.g. a freshly provisioned or wiped PVC.
if [ "$SKIPUPDATE" != "true" ]; then
    install
elif [ ! -x "$INSTALL_DIR/FactoryServer.sh" ]; then
    LogWarn "SKIPUPDATE=true but server files missing; installing anyway"
    install
else
    LogWarn "SKIPUPDATE=true, not updating the game"
fi

if [ ! -x "$INSTALL_DIR/FactoryServer.sh" ]; then
    LogError "Install finished but $INSTALL_DIR/FactoryServer.sh is missing. Contents:"
    ls -la "$INSTALL_DIR" || true
    exit 1
fi

# Mods: install/update from ficsit.app on every boot. MODS is a space-separated
# list of ficsit mod references, each optionally pinned as ref@version (default
# ">=0.0.0" = latest). ficsit-cli pulls SML and dependencies automatically and
# writes server-target mod files into $INSTALL_DIR/FactoryGame/Mods (on the PVC).
# Runs AFTER SteamCMD because a game update can overwrite the Mods directory.
# The ficsit config dir is container-ephemeral, so it is rebuilt clean each boot.
FICSIT_LOCAL_DIR="/home/steam/.local/share/ficsit"
if [ -n "$(echo "$MODS" | tr -d '[:space:]')" ]; then
    LogAction "Configuring mods via ficsit-cli"
    mkdir -p "$FICSIT_LOCAL_DIR"
    mods_json=""
    for entry in $MODS; do
        ref="${entry%@*}"
        ver=">=0.0.0"
        case "$entry" in *@*) ver="${entry##*@}";; esac
        [ -n "$mods_json" ] && mods_json="${mods_json},"
        mods_json="${mods_json}\"${ref}\":{\"version\":\"${ver}\",\"enabled\":true}"
    done
    printf '{"profiles":{"server":{"mods":{%s},"name":"server","required_targets":[]}},"selected_profile":"server","version":0}\n' \
        "$mods_json" > "$FICSIT_LOCAL_DIR/profiles.json"
    chown -R steam:steam "$FICSIT_LOCAL_DIR"
    LogInfo "Mods requested: $MODS"
    gosu steam ficsit --local-dir "$FICSIT_LOCAL_DIR" installation add "$INSTALL_DIR" server || true
    if ! gosu steam ficsit --local-dir "$FICSIT_LOCAL_DIR" apply; then
        LogError "ficsit apply failed - starting server without applying mod changes"
    fi
else
    LogInfo "MODS empty - running vanilla (no mods)"
fi

# shellcheck disable=SC2317
term_handler() {
    LogAction "Caught SIGTERM, stopping server"
    kill -SIGTERM "$(pidof FactoryServer-Linux-Shipping)" 2>/dev/null
    tail --pid="$killpid" -f 2>/dev/null
}
trap 'term_handler' SIGTERM

LogAction "Starting Satisfactory dedicated server"
cd "$INSTALL_DIR" || exit 1

# No -multihome: the server binds all interfaces by default (multihome is for
# pinning a single IP). -Port sets 7777 TCP+UDP, -ReliablePort sets 8888 TCP.
# Ports per the official wiki (15000/15777 removed in Patch 1.0).
#
# MaxPlayers has no short-form flag and no Server Manager UI field; the only
# launch-time control is the UE4 -ini override, which takes precedence over
# Game.ini at the same key (so no config-file write/race needed).
gosu steam ./FactoryServer.sh \
    -log \
    -unattended \
    -Port="$SERVER_PORT" \
    -ReliablePort="$RELIABLE_PORT" \
    "-ini:Game:[/Script/Engine.GameSession]:MaxPlayers=${MAXPLAYERS:-4}" &

# Process ID of the launched server
killpid="$!"
wait "$killpid"
