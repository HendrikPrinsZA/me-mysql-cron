#!/bin/bash

# LOCAL VARIABLES
BASEDIR="$(pwd)"
declare -a CONFIGS # Arry of available config files
DB_HOST=""
DB_USER=""
DB_NAME=""
DB_PASS=""

SUGGESTED_ACTION=""

function mainMenu {
    clearBuffer
    loadConfigs

    printf "\n"
    echo "-----------------------------------------------"
    echo "  Main Menu"
    echo "-----------------------------------------------"
    echo "  1 = Select Config"
    echo "  2 = Create/Update Config"
    echo "..............................................."
    echo "  0 = Exit"
    echo "-----------------------------------------------"
    printf "\n"
    read -p "  Choose a number? " CHOSEN_OPTION
    printf "\n"

    if echo $CHOSEN_OPTION | egrep -q '^[0-3]+$'; then
        case "$CHOSEN_OPTION" in
        0) echo "Bye ... "
            #exit 1
           ;;
        1) availableConfigs
           ;;

        2) createEditConfig
           ;;

        3) echo "Test Config"
           ;;
        esac
    else
        echo "Invalid Option "$CHOSEN_OPTION
        mainMenu
    fi

}

function availableConfigs {
    clearBuffer
    COUNTER=0
    printf "\n"
    echo "-----------------------------------------------"
    echo "  Select Config"
    echo "-----------------------------------------------"
    # for i in ${CONFIGS}; do
    #     let COUNTER=(COUNTER+1)
    #     echo "  ${COUNTER} = ${i}"
    # done
    # for i in ${CONFIGS[*]}; do
    #     let COUNTER=(COUNTER+1)
    #     echo "  ${COUNTER} = ${i}"
    # done
    listConfigs
    echo "..............................................."
    echo "  0 = Main Menu"
    echo "-----------------------------------------------"
    printf "\n"
    read -p "  Choose a number? " CHOSEN_OPTION
    printf "\n"

    if echo $CHOSEN_OPTION | egrep -q "^[0-$COUNTER]+$"; then

        if echo $CHOSEN_OPTION | egrep -q "^[1-$COUNTER]+$"; then
            selectConfig $CHOSEN_OPTION
        else 
            mainMenu
        fi
    else
        echo "Invalid Option "$CHOSEN_OPTION
        availableConfigs
    fi
}

function selectConfig { # $1 = CONFIG_INDEX
    clearBuffer
    CONFIG_INDEX=$1
    printf "\n"
    echo "-----------------------------------------------"
    echo "  Config: ${CONFIGS[CONFIG_INDEX-1]}"
    echo "-----------------------------------------------"
    echo "  1 = Update (Wizard)"
    echo "  2 = Edit/View (Manual)"
    echo "  3 = Delete"
    echo "  4 = Trigger Export"
    echo "  5 = Trigger Import"
    echo "  6 = Trigger Export Then Import"
    echo "..............................................."
    echo "  0 = Main Menu"
    echo "-----------------------------------------------"
    printf "\n"
    read -p "  Choose a number? " CHOSEN_OPTION
    printf "\n"

    if echo $CHOSEN_OPTION | egrep -q '^[0-6]+$'; then
        case "$CHOSEN_OPTION" in
        0) echo "Continue"
            mainMenu
           ;;

        1) echo "  Loaded config for '${CONFIGS[CONFIG_INDEX-1]}'"
           parseConfig ${CONFIGS[CONFIG_INDEX-1]}
           read -p "  Hit Enter to continue " DUMMY
           configWizard "${CONFIGS[CONFIG_INDEX-1]}"
           ;;

        2) vi ${CONFIGS[CONFIG_INDEX-1]}
           selectConfig $CONFIG_INDEX
           ;;

        3) deleteConfig $CONFIG_INDEX
           ;;

        4) triggerDriver ${CONFIGS[CONFIG_INDEX-1]} "export"
           read -p "  Hit Enter to continue " DUMMY
           selectConfig $CONFIG_INDEX
           ;;

        5) triggerDriver ${CONFIGS[CONFIG_INDEX-1]} "import"
           read -p "  Hit Enter to continue " DUMMY
           selectConfig $CONFIG_INDEX
           ;;

        6) triggerDriver ${CONFIGS[CONFIG_INDEX-1]} "export_then_import"
           read -p "  Hit Enter to continue " DUMMY
           selectConfig $CONFIG_INDEX
           ;;

        esac
    else
        echo "Invalid Option "$CHOSEN_OPTION
        mainMenu
    fi
}

function triggerDriver { # $1 = CONFIG_PATH $2 = ACTION
    clearBuffer
    CONFIG_PATH=$1
    ACTION=$2

    parseConfig $CONFIG_PATH

    printf "\n"
    echo "-----------------------------------------------"
    echo "  Triger Cron Driver"
    echo "..............................................."
    echo "  Command: ./cron.driver.sh -c $CONFIG_PATH -a '$ACTION' -p '$SECURITYGUID'"
    echo "-----------------------------------------------"
    read -p "  Are you sure? (y/n) " RESP
    if [ "$RESP" = "y" ]; then
        # sh cron.driver.sh -c $CONFIG_PATH -a $ACTION -p $SECURITYGUID
        ./cron.driver.sh -c $CONFIG_PATH -a $ACTION -p $SECURITYGUID
    fi

}

function deleteConfig { # $1 = CONFIG_INDEX
    clearBuffer
    printf "\n"
    echo "-----------------------------------------------"
    echo "  Delete Config: ${CONFIGS[CONFIG_INDEX-1]}"
    echo "-----------------------------------------------"
    read -p "  Are you sure? (y/n) " RESP
    if [ "$RESP" = "y" ]; then
        rm ${CONFIGS[CONFIG_INDEX-1]}
        echo "  Deleted Config '${CONFIGS[CONFIG_INDEX-1]}'"
        read -p "  Hit Enter to continue " DUMMY
        loadConfigs
        availableConfigs
    else
        availableConfigs
    fi
}

function createEditConfig {
    # clearBuffer
    printf "\n"
    echo "-----------------------------------------------"
    echo "  Create/Update Config"
    echo "..............................................."
    echo "  Current Configs: "
    listConfigsBare
    echo "-----------------------------------------------"
    echo "  Config details"
    read -p "  Name: " CONFIG_NAME
    CONFIG_NAME=${CONFIG_NAME%.cfg}
    CONFIG_NAME=${CONFIG_NAME}.cfg


    if [ ! -f "configs/${CONFIG_NAME}" ]; then

        read -p "  Are you sure you want to create '${CONFIG_NAME}'? (y/n) " RESP
        if [ "$RESP" = "y" ]; then
            SUGGESTED_ACTION="FULL_WIZARD"
            cp config_template.cfg configs/$CONFIG_NAME
            parseConfig configs/$CONFIG_NAME
            configWizard configs/$CONFIG_NAME
        else
            createEditConfig
        fi

    else 

        read -p "  Are you sure you want to update '${CONFIG_NAME}'? (y/n) " RESP
        if [ "$RESP" = "y" ]; then
            parseConfig configs/$CONFIG_NAME
            configWizard configs/$CONFIG_NAME
        else
            createEditConfig
        fi

    fi

}

function configWizard_SECURITYGUID {
    printf "\n"
    echo "  1. Password"
    printf "\n"
    echo "     (i) The password protects the script from accidentally being executed"
    printf "\n"
    echo "     Required: Yes"
    echo "     Default Value: [NONE]"
    if [ ! "$SECURITYGUID" = "" ]; then
    echo "     Current Value: $SECURITYGUID"
    fi
    printf "\n"
    read -p "  Password: " SECURITYGUID
    if [ "$SECURITYGUID" = "" ]; then
    echo "     Error: Not allowed to be empty"
    configWizard_SECURITYGUID
    fi
}

function configWizard_DUMP_FOLDER_NAME {
    printf "\n"
    echo "  2. Dump Folder Path"
    printf "\n"
    echo "     (i) The database dumps will be stored and fetched in this directory"
    printf "\n"
    echo "     Required: Yes"
    echo "     Default Value: $CONFIG_NAME_NO_EXT"
    if [ "$DUMP_FOLDER_NAME" = "" ]; then
    echo "     Current Value: $DUMP_FOLDER_NAME"
    fi
    printf "\n"
    read -p "  Dump Folder Path: " DUMP_FOLDER_NAME
    if [ "$DUMP_FOLDER_NAME" = "" ]; then
    echo "     Error: Not allowed to be empty"
    configWizard_DUMP_FOLDER_NAME
    fi
}

function configWizard_NOTIFY_EMAIL_ADDRESS {
    printf "\n"
    echo "  3. Notify Email Address"
    printf "\n"
    echo "     (i) If email notification is enabled this address will be notified of all cron activity"
    printf "\n"
    echo "     Required: No"
    echo "     Default Value: [NONE]"
    if [ "$NOTIFY_EMAIL_ADDRESS" = "" ]; then
    echo "     Current Value: $NOTIFY_EMAIL_ADDRESS"
    fi
    printf "\n"
    read -p "  Notify Email Address: " NOTIFY_EMAIL_ADDRESS
}

function configWizard_MAX_DUMPS {
    printf "\n"
    echo "  4. Max Dumps"
    printf "\n"
    echo "     (i) The cron will automatically remove older dumps if the limit is reached"
    echo "         If the value is 0 it will not remove any dumps"
    printf "\n"
    echo "     Required: Yes"
    echo "     Default Value: 0"
    if [ "$MAX_DUMPS" = "" ]; then
    echo "     Current Value: $MAX_DUMPS"
    fi
    printf "\n"
    read -p "  Max Dumps: " MAX_DUMPS
}

function configWizard_DB_SOURCE {
    printf "\n"
    echo "  5. Source Database"
    printf "\n"
    echo "     (i) This database will be used to create the database dumps"
    printf "\n"
    echo "     Required: Yes"
    if [ ! "$DB_SOURCE_HOST" = "" ]; then
    echo "     Current Values"
    echo "     Host: $DB_SOURCE_HOST"
    echo "     User: $DB_SOURCE_USER"
    echo "     Name: $DB_SOURCE_NAME"
    echo "     Pass: $DB_SOURCE_PASS"
    fi

    setDatabaseConnection
    DB_SOURCE_HOST=${DB_HOST}
    DB_SOURCE_USER=${DB_USER}
    DB_SOURCE_NAME=${DB_NAME}
    DB_SOURCE_PASS=${DB_PASS}
}

function configWizard_DB_TARGET_1 {
    printf "\n"
    echo "  6. Target Database 1"
    printf "\n"
    echo "     (i) This database will be used to refresh (Clear and import the latest dump)"
    printf "\n"
    echo "     Required: Yes"
    echo "     Rotation: Odd weeks"
    if [ ! "$DB_TARGET_1_HOST" = "" ]; then
    echo "     Current Values"
    echo "     Host: $DB_TARGET_1_HOST"
    echo "     User: $DB_TARGET_1_USER"
    echo "     Name: $DB_TARGET_1_NAME"
    echo "     Pass: $DB_TARGET_1_PASS"
    fi

    setDatabaseConnection
    DB_TARGET_1_HOST=${DB_HOST}
    DB_TARGET_1_USER=${DB_USER}
    DB_TARGET_1_NAME=${DB_NAME}
    DB_TARGET_1_PASS=${DB_PASS}
}

function configWizard_DB_TARGET_2 {
    printf "\n"
    echo "  7. Target Database 2"
    printf "\n"
    echo "     (i) This database will be used to refresh (Clear and import the latest dump)"
    echo "         If you are not using 2 target databases, enter the same details as for target database 1"
    printf "\n"
    echo "     Required: Yes"
    echo "     Rotation: Even weeks"
    if [ ! "$DB_TARGET_2_HOST" = "" ]; then
    echo "     Current Values"
    echo "     Host: $DB_TARGET_2_HOST"
    echo "     User: $DB_TARGET_2_USER"
    echo "     Name: $DB_TARGET_2_NAME"
    echo "     Pass: $DB_TARGET_2_PASS"
    fi

    setDatabaseConnection
    DB_TARGET_2_HOST=${DB_HOST}
    DB_TARGET_2_USER=${DB_USER}
    DB_TARGET_2_NAME=${DB_NAME}
    DB_TARGET_2_PASS=${DB_PASS}
}

function configWizard { # $1 = CONFIG_PATH
    clearBuffer
    CONFIG_PATH=$1

    CONFIG_NAME=${CONFIG_PATH#*/}
    CONFIG_NAME_NO_EXT=dumps/${CONFIG_NAME%.cfg}


    printf "\n"
    echo "-----------------------------------------------"
    echo "  Config Wizard '$CONFIG_NAME'"
    if [ ! "$LAST_UPDATED" = "" ]; then
        echo "    Last Updated: $LAST_UPDATED"
    fi
    echo "-----------------------------------------------"
    echo "  1 = Password"
    echo "  2 = Dump Folder Path"
    echo "  3 = Notify Email Address"
    echo "  4 = Max Dumps"
    echo "  5 = Source Database"
    echo "  6 = Target Database 1"
    echo "  7 = Target Database 2"
    echo "  8 = All (1-7)"
    echo "..............................................."
    echo "  9 = Save Changes"
    if [ "$SUGGESTED_ACTION" = "SAVE_CHANGES" ]; then
        echo "  10 = Reset Unsaved Changes"
    fi
    echo "..............................................."
    echo "  0 = Main Menu"
    echo "-----------------------------------------------"
    printf "\n"

    # SUGGESTED_ACTION
    if [ "$SUGGESTED_ACTION" = "SAVE_CHANGES" ]; then
        echo "***********************************************"
        echo "* Recommended: 9 = Save Changes               *"
        echo "***********************************************"
        printf "\n"
    fi

    if [ "$SUGGESTED_ACTION" = "FULL_WIZARD" ]; then
        echo "***********************************************"
        echo "* Recommended: 8 = All (1-7)                   *"
        echo "***********************************************"
        printf "\n"
    fi

    read -p "  Choose a number? " CHOSEN_OPTION
    printf "\n"

    if echo $CHOSEN_OPTION | egrep -q '^[0-9]+$'; then
        case "$CHOSEN_OPTION" in
        0) echo "Continue"
            mainMenu
           ;;

        8)  configWizard_SECURITYGUID
            configWizard_DUMP_FOLDER_NAME
            configWizard_NOTIFY_EMAIL_ADDRESS
            configWizard_MAX_DUMPS
            configWizard_DB_SOURCE
            configWizard_DB_TARGET_1
            configWizard_DB_TARGET_2

            SUGGESTED_ACTION="SAVE_CHANGES"
            configWizard $CONFIG_PATH
            ;;

        9)  read -p "  Are you sure you want to save your changes of '${CONFIG_PATH}'? (y/n) " RESP
            if [ "$RESP" = "y" ]; then
                saveConfigFile $CONFIG_PATH
                SUGGESTED_ACTION=""
                echo "  Saved Changed"
                read -p "  Hit Enter to continue " DUMMY
                parseConfig $CONFIG_PATH
                configWizard $CONFIG_PATH
            else
                echo "  Did not save changed"
                read -p "  Hit Enter to continue " DUMMY
                configWizard $CONFIG_PATH
            fi
            ;;

        10)  read -p "  Are you sure you want to reset unsaved your changes of '${CONFIG_PATH}'? (y/n) " RESP
            if [ "$RESP" = "y" ]; then
                echo "  Reset Changed"
                read -p "  Hit Enter to continue " DUMMY
                parseConfig $CONFIG_PATH
                configWizard $CONFIG_PATH
            else
                echo "  Did not reset changed"
                read -p "  Hit Enter to continue " DUMMY
                configWizard $CONFIG_PATH
            fi
            ;;

        1) configWizard_SECURITYGUID
           SUGGESTED_ACTION="SAVE_CHANGES"
           configWizard $CONFIG_PATH
           ;;

        2) configWizard_DUMP_FOLDER_NAME
           SUGGESTED_ACTION="SAVE_CHANGES"
           configWizard $CONFIG_PATH
           ;;
           
        3) configWizard_NOTIFY_EMAIL_ADDRESS
           SUGGESTED_ACTION="SAVE_CHANGES"
           configWizard $CONFIG_PATH
           ;;
           
        4) configWizard_MAX_DUMPS
           SUGGESTED_ACTION="SAVE_CHANGES"
           configWizard $CONFIG_PATH
           ;;
           
        5) configWizard_DB_SOURCE
           SUGGESTED_ACTION="SAVE_CHANGES"
           configWizard $CONFIG_PATH
           ;;
           
        6) configWizard_DB_TARGET_1
           SUGGESTED_ACTION="SAVE_CHANGES"
           configWizard $CONFIG_PATH
           ;;
           
        7) configWizard_DB_TARGET_2
           SUGGESTED_ACTION="SAVE_CHANGES"
           configWizard $CONFIG_PATH
           ;;
           
        esac
    else
        echo "Invalid Option "$CHOSEN_OPTION
        read -p "  Hit Enter to continue " DUMMY
        configWizard
    fi

}

function saveConfigFile { # $1 = CONFIG_PATH
    CONFIG_PATH=$1
    echo "LAST_UPDATED=\"$(date +"%Y-%m-%d %H:%M:%S")\"" > $CONFIG_PATH
    cat <<EOT >> $CONFIG_PATH
# General Variable
SECURITYGUID="${SECURITYGUID}"
DUMP_FOLDER_NAME="${DUMP_FOLDER_NAME}"
NOTIFY_EMAIL_ADDRESS="${NOTIFY_EMAIL_ADDRESS}"
MAX_DUMPS="${MAX_DUMPS}"

# Source Database Details
DB_SOURCE_HOST="${DB_SOURCE_HOST}"
DB_SOURCE_USER="${DB_SOURCE_USER}"
DB_SOURCE_NAME="${DB_SOURCE_NAME}"
DB_SOURCE_PASS="${DB_SOURCE_PASS}"

# Target Databases Details
# Target Database 1 - Used on weeks that are ODD
DB_TARGET_1_HOST="${DB_TARGET_1_HOST}"
DB_TARGET_1_USER="${DB_TARGET_1_USER}"
DB_TARGET_1_NAME="${DB_TARGET_1_NAME}"
DB_TARGET_1_PASS="${DB_TARGET_1_PASS}"

# Target Database 2 - Used on weeks that are EVEN
DB_TARGET_2_HOST="${DB_TARGET_2_HOST}"
DB_TARGET_2_USER="${DB_TARGET_2_USER}"
DB_TARGET_2_NAME="${DB_TARGET_2_NAME}"
DB_TARGET_2_PASS="${DB_TARGET_2_PASS}"
EOT
#     cat >"$BASEDIR/$CONFIG_PATH" <<EOL
# # General Variable
# SECURITYGUID="${SECURITYGUID}"
# DUMP_FOLDER_NAME="dumps/my_prod_dumps"
# NOTIFY_EMAIL_ADDRESS="johndoe@company.com"

# # Source Database Details
# DB_SOURCE_HOST=""
# DB_SOURCE_USER=""
# DB_SOURCE_NAME=""
# DB_SOURCE_PASS=""

# # Target Databases Details
# # Target Database 1 - Used on weeks that are ODD
# DB_TARGET_1_HOST=""
# DB_TARGET_1_USER=""
# DB_TARGET_1_NAME=""
# DB_TARGET_1_PASS=""

# # Target Database 2 - Used on weeks that are EVEN
# DB_TARGET_2_HOST=""
# DB_TARGET_2_USER=""
# DB_TARGET_2_NAME=""
# DB_TARGET_2_PASS=""
# EOL
#     cat "$BASEDIR/$CONFIG_PATH"
}

function clearBuffer {
    clear
}

function listConfigsBare {
    COUNTER=0
    for i in ${CONFIGS[*]}; do
        let COUNTER=(COUNTER+1)
        ${var#*: }
        echo "  - ${i#*/}"
    done
}

function listConfigs {
    COUNTER=0
    for i in ${CONFIGS[*]}; do
        let COUNTER=(COUNTER+1)
        ${var#*: }
        echo "  ${COUNTER} = ${i#*/}"
    done
}

function loadConfigs {
    shopt -s nullglob
    CONFIGS=(configs/*)
}

function parseConfig { # $1 = CONFIG_PATH
    configfile=$1
    configfile_secured='temp_config_file_secured.cfg'

    # check if the file contains something we don't want
    if egrep -q -v '^#|^[^ ]*=[^;]*' "$configfile"; then
      egrep '^#|^[^ ]*=[^;&]*'  "$configfile" > "$configfile_secured"
      configfile="$configfile_secured"
    fi

    # now source it, either the original or the filtered variant
    source "$configfile"
    rm $configfile
}

function setDatabaseConnection {
    printf "\n"
    read -p "  Host: " DB_HOST
    read -p "  User: " DB_USER
    read -p "  DB Name: " DB_NAME
    read -p "  Pass: " -s DB_PASS

    verifyConnection ${DB_HOST} ${DB_USER} ${DB_PASS} ${DB_NAME}

    printf "\n"
    if [ ! "$VERIFY_CONNECTION_RESULT" = "success" ]; then
        echo "  Result: Connection Failed"
        setDatabaseConnection
    else
        echo "  Result: Connection Passed"
    fi
}

# Check MySQL password
function verifyConnection {
    echo exit | mysql --host=$1 --user=$2 --password=$3 $4 -B 2>/dev/null
    if [ "$?" -gt 0 ]; then
        VERIFY_CONNECTION_RESULT="failed"
    else
        VERIFY_CONNECTION_RESULT="success"
    fi
}

mainMenu
