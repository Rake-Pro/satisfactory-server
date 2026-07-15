#!/bin/bash

#================
# Log Definitions
#================
export LINE='\n'                        # Line Break
export RESET='\033[0m'                  # Text Reset
export WhiteText='\033[0;37m'           # White

# Bold
export RedBoldText='\033[1;31m'         # Red
export GreenBoldText='\033[1;32m'       # Green
export YellowBoldText='\033[1;33m'      # Yellow
export CyanBoldText='\033[1;36m'        # Cyan
#================
# End Log Definitions
#================

LogInfo() {
  Log "$1" "$WhiteText"
}
LogWarn() {
  Log "$1" "$YellowBoldText"
}
LogError() {
  Log "$1" "$RedBoldText"
}
LogSuccess() {
  Log "$1" "$GreenBoldText"
}
LogAction() {
  Log "$1" "$CyanBoldText" "====" "===="
}
Log() {
  local message="$1"
  local color="$2"
  local prefix="$3"
  local suffix="$4"
  printf "$color%s$RESET$LINE" "$prefix$message$suffix"
}

# Single SteamCMD install/update pass.
# When STEAMBETA=true, target the named beta branch (e.g. "experimental")
# instead of the default public branch.
run_steamcmd() {
  if [ "$STEAMBETA" = "true" ] && [ -n "$STEAMBETAID" ]; then
    LogInfo "Installing beta branch: $STEAMBETAID"
    /home/steam/steamcmd/steamcmd.sh \
      +force_install_dir "$INSTALL_DIR" \
      +login anonymous \
      +app_update "$STEAMAPPID" -beta "$STEAMBETAID" validate \
      +quit
  else
    /home/steam/steamcmd/steamcmd.sh +runscript /home/steam/server/install.scmd
  fi
}

# SteamCMD's exit code is unreliable, so treat the app manifest as the source
# of truth: StateFlags 4 = fully installed. Anything else (6 = update
# required/aborted, missing file) means the update did not complete.
update_succeeded() {
  local manifest="$INSTALL_DIR/steamapps/appmanifest_${STEAMAPPID}.acf"
  [ -f "$manifest" ] && grep -q '"StateFlags"[[:space:]]*"4"' "$manifest"
}

# Install/update the Satisfactory dedicated server via SteamCMD, with retries.
# SteamCMD has a known transient failure mode under anonymous login ("state is
# 0x6 after update job" / "Missing configuration") where re-running app_update
# succeeds. The retries MUST happen within this container run: ~/Steam is
# container-ephemeral, so every pod restart is a cold-cache first attempt and
# restarting the pod never gets past attempt 1. If retries don't clear it,
# wipe steamapps/ (stale update state on the PVC keeps the failure sticky) and
# make one final full-validate attempt. Returns nonzero if all attempts fail.
install() {
  LogAction "Starting server install"
  local attempt
  for attempt in 1 2 3; do
    if [ "$attempt" -gt 1 ]; then
      LogWarn "SteamCMD update failed, retrying (attempt $attempt/3)"
      sleep 10
    fi
    run_steamcmd
    if update_succeeded; then
      LogSuccess "SteamCMD update complete (attempt $attempt)"
      return 0
    fi
  done
  LogWarn "3 attempts failed; wiping $INSTALL_DIR/steamapps and making one final full-validate attempt"
  rm -rf "${INSTALL_DIR:?}/steamapps"
  run_steamcmd
  if update_succeeded; then
    LogSuccess "SteamCMD update complete after steamapps wipe"
    return 0
  fi
  return 1
}
