#!/bin/bash
# Satisfactory-specific helpers.
#
# The shared helpers (LogInfo/LogWarn/LogError/LogSuccess/LogAction/Log,
# require_env, steamcmd_installed, steamcmd_run, steamcmd_update,
# remap_steam_user) come from the steamcmd-base image and are NOT duplicated
# here.
# shellcheck source=/dev/null
source /opt/scripts/functions.sh

# Install/update the Satisfactory dedicated server via SteamCMD, with retries.
# SteamCMD has a known transient failure mode under anonymous login ("state is
# 0x6 after update job" / "Missing configuration") where re-running app_update
# succeeds. The retries MUST happen within this container run: ~/Steam is
# container-ephemeral, so every pod restart is a cold-cache first attempt and
# restarting the pod never gets past attempt 1. If retries don't clear it,
# STEAMCMD_WIPE_ON_FAIL makes the helper wipe steamapps/ (stale update state on
# the PVC keeps the failure sticky) and take one final full-validate attempt.
# Returns nonzero if all attempts fail.
#
# Beta branches: STEAM_BETA is the canonical (base image) variable. The older
# STEAMBETA=true + STEAMBETAID pair is still honoured and wins when set.
install() {
  if [ "${STEAMBETA:-false}" = "true" ] && [ -n "${STEAMBETAID:-}" ]; then
    LogInfo "Installing beta branch: $STEAMBETAID"
    export STEAM_BETA="$STEAMBETAID"
  fi
  export STEAMCMD_WIPE_ON_FAIL=true
  steamcmd_update "$STEAMAPPID" validate
}
