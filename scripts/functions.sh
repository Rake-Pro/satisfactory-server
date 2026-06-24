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

# Install/update the Satisfactory dedicated server via SteamCMD.
# When STEAMBETA=true, target the named beta branch (e.g. "experimental")
# instead of the default public branch.
install() {
  LogAction "Starting server install"
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
