#!/bin/bash


MYSQL=$(which mysql)
AWK=$(which awk)
GREP=$(which grep)

# WHAT THIS DOES
# --------------
# Choose source database
# Create source dump folder "<dbname>_<datetime>"
# Create source dump scripts inside dump folder

TARGETDIR="$(pwd)"


function setDatabaseDetails {
    # We alternate between $DB_TARGET_1 & $DB_TARGET_2:
    # - $DB_TARGET_1: Odd Weeks
    # - $DB_TARGET_2: Even Weeks

    weekno=$(date +%V)
    rem=$(expr $weekno % 2)
    if [ $rem -eq 1 ]; then
        DB_HOST=$DB_TARGET_1_HOST
        DB_USER=$DB_TARGET_1_USER
        DB_NAME=$DB_TARGET_1_NAME
        DB_PASS=$DB_TARGET_1_PASS
    else
        DB_HOST=$DB_TARGET_2_HOST
        DB_USER=$DB_TARGET_2_USER
        DB_NAME=$DB_TARGET_2_NAME
        DB_PASS=$DB_TARGET_2_PASS
    fi
}

function checkDatabaseActivity {
    diff=$($MYSQL -h$DB_HOST -u$DB_USER -p$DB_PASS $DB_NAME -s -N -e "SELECT DATEDIFF(NOW(), datecreated) FROM eventlog ORDER BY eventlogid DESC LIMIT 1;")
    # if [ $diff -lt 5 ]; then
    if [ $diff -lt 0 ]; then
        php "cron.email.php" h=$DB_HOST u=$DB_USER n=$DB_NAME diff=$diff result=fail reason="Database was in use this week"
        exit 1
    fi
}

function clearDatabase {
    TABLES=$($MYSQL -h$DB_HOST -u$DB_USER -p$DB_PASS $DB_NAME -e "SHOW FULL TABLES WHERE Table_type != 'VIEW';" | $AWK '{ print $1}' | $GREP -v '^Tables' )
    for t in $TABLES
    do
        $MYSQL -h$DB_HOST -u$DB_USER -p$DB_PASS $DB_NAME -e "SET FOREIGN_KEY_CHECKS=0; SET UNIQUE_CHECKS=0;DROP TABLE \`$t\`;SET FOREIGN_KEY_CHECKS=1; SET UNIQUE_CHECKS=1;"
    done

    SQLSTRINGS=$($MYSQL -h$DB_HOST -u$DB_USER -p$DB_PASS $DB_NAME -e "SELECT R.ROUTINE_NAME FROM information_schema.ROUTINES R WHERE R.ROUTINE_SCHEMA = '$DB_NAME' AND R.ROUTINE_TYPE='PROCEDURE';" | $AWK '{ print $1}' | $GREP -v '^Tables' )
    for s in $SQLSTRINGS
    do
        $MYSQL -h$DB_HOST -u$DB_USER -p$DB_PASS $DB_NAME -e "DROP PROCEDURE IF EXISTS \`$s\`;"
    done

    SQLSTRINGS=$($MYSQL -h$DB_HOST -u$DB_USER -p$DB_PASS $DB_NAME -e "SELECT R.ROUTINE_NAME FROM information_schema.ROUTINES R WHERE R.ROUTINE_SCHEMA = '$DB_NAME' AND R.ROUTINE_TYPE='FUNCTION';" | $AWK '{ print $1}' | $GREP -v '^Tables' )
    for s in $SQLSTRINGS
    do
        $MYSQL -h$DB_HOST -u$DB_USER -p$DB_PASS $DB_NAME -e "DROP FUNCTION IF EXISTS \`$s\`;"
    done
}

function importDatabase {
    # Get latest export folder / zip from
    latestexport=$(tail -1 "$DUMP_FOLDER_NAME/export.log" | head -1)

    if [[ $latestexport == *".zip"* ]]
    then
        # Unzip compressed folder
        exportfolder=${latestexport/.zip/}
        unzip -o $latestexport -d $exportfolder
    else
        # Use folder as is
        exportfolder=latestexport
    fi

    if [ ! -d $exportfolder ]; then
        printf "\n"
        echo "Folder ${exportfolder} does not exist!"
    fi

    # Import Scripts
    # Import Schema
    printf "\n"
    echo "Importing Schema..."
    mysql -u${DB_USER} -p${DB_PASS} -h${DB_HOST} $DB_NAME < "${exportfolder}/1_schema.sql"
    # Import SP and Funcs
    printf "\n"
    echo "Importing Functions and Stored Procedures..."
    mysql -u${DB_USER} -p${DB_PASS} -h${DB_HOST} $DB_NAME < "${exportfolder}/2_spfunc.sql"
    # Import Data
    printf "\n"
    echo "Importing Data..."
    mysql -u${DB_USER} -p${DB_PASS} -h${DB_HOST} $DB_NAME < "${exportfolder}/3_data.sql"
    # Import Triggers
    printf "\n"
    echo "Importing Triggers..."
    mysql -u${DB_USER} -p${DB_PASS} -h${DB_HOST} $DB_NAME < "${exportfolder}/4_triggers.sql"
    # Import Views
    printf "\n"
    echo "Importing Views..."
    mysql -u${DB_USER} -p${DB_PASS} -h${DB_HOST} $DB_NAME < "${exportfolder}/5_views.sql"

    rm -rf $exportfolder
}

function emailImportComplete {
    php "cron.email.php" to=$NOTIFY_EMAIL_ADDRESS h=$DB_HOST u=$DB_USER n=$DB_NAME diff=$diff result=success reason="Successfully imported database"
}

function doCronImport {
    setDatabaseDetails
    # emailImportStarted
    # checkDatabaseActivity
    clearDatabase
    importDatabase
    emailImportComplete
}

TARGETDIR="$(pwd)"

doCronImport

cd $TARGETDIR

# exit
