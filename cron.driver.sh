#!/bin/bash
# Example Call:
# sh cron.driver.sh -c 'configs/cron_barclays.cfg' -a 'export' -p 'cLevv@cr0n$'

TARGETDIR="$(pwd)"

# cd "$(pwd)/crons"

# Definitions:
# Config:   -c [config file path]
# Action:   -a export | import | export_then_import
# Password: -p SECURITYGUID defined in the config
#
while getopts ":c:a:p:" opt; do
  case $opt in
    c) CONFIG="$OPTARG"
    ;;
    a) ACTION="$OPTARG"
    ;;
    p) PASSWORD="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

function parseConfig {
    configfile="${CONFIG}"
    configfile_secured='/tmp/cron.cfg'

    # check if the file contains something we don't want
    if egrep -q -v '^#|^[^ ]*=[^;]*' "$configfile"; then
      egrep '^#|^[^ ]*=[^;&]*'  "$configfile" > "$configfile_secured"
      configfile="$configfile_secured"
    fi

    # now source it, either the original or the filtered variant
    source "$configfile"
}

# Check if config exists
if [ ! -f "${CONFIG}" ]; then
    printf "\n"
    echo "Config File '${CONFIG}' does not exist!"
    exit
else
    printf "\n"
    echo "Loaded Config File '${CONFIG}'!"
    parseConfig
fi

# Check Password
if [ "$PASSWORD" != "$SECURITYGUID" ]; then
    echo "Invalid password: '${PASSWORD}'!"
    exit
fi

# Check if action is valid
if [ "$ACTION" == "export" ]; then
    echo "Export Only"
    source "./cron.export.sh"
    # exit
elif  [ "$ACTION" == "import" ]; then
    echo "Import Only"
    source "./cron.import.sh"
    # exit
elif [ "$ACTION" == "export_then_import" ]; then
    echo "Export Then Import"
    source "./cron.export.sh"
    source "./cron.import.sh"
    # exit
else
    # echo "Invalid Action (-a). Vailable Options: 'export', 'import', 'export_then_import'"
    echo "Invalid Action (-a). Vailable Options: 'export', 'import', 'export_then_import'"
    # exit
fi

# exit