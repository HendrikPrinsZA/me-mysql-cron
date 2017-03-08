#!/bin/bash

# WHAT THIS DOES
# --------------
# - Exports the Database
# - Compresses the export folder (If system has 'zip')
# - Appends the export.log (Used for sync importing)
#
# IMPORTANT: See cron.cfg

function logExportJob {
    logfile="${TARGETDIR}/${DUMP_FOLDER_NAME}/export.log"
    if [ ! -f "$logfile" ]; then
        mkdir -p "`dirname \"$logfile\"`" 2>/dev/null
    fi
    echo $1 >> $logfile
}

function compressAndRemoveFolder {
    if type zip 2>/dev/null; then
        zip -r -j "${TARGETDIR_DUMP_FOLDER}.zip" "${TARGETDIR_DUMP_FOLDER}"
        logExportJob "${TARGETDIR_DUMP_FOLDER}.zip"
        rm -rf "${TARGETDIR_DUMP_FOLDER}"
    else
        logExportJob "${TARGETDIR_DUMP_FOLDER}"
    fi
}

function doCronExport {
    # createDumpFolder
    DUMP_FOLDER="${DB_SOURCE_NAME}_"$(date +"%Y%m%d_%H%M%S")
    TARGETDIR_DUMP_FOLDER="${TARGETDIR}/${DUMP_FOLDER_NAME}/${DUMP_FOLDER}"

    mkdir -p $TARGETDIR_DUMP_FOLDER
    printf "\n"

    # Full db export
    exportFULL
}

function getIgnoreTableList {
    local IGNORE_TABLE_LIST=""
    while read tbl; do
        IGNORE_TABLE_LIST=" $IGNORE_TABLE_LIST --ignore-table=$DB_SOURCE_NAME.$tbl"
    done < $TARGETDIR/$1
    echo $IGNORE_TABLE_LIST
}

function generateIgnoreViewsFile {
    local IGNORE_VIEWS_FILE="bin/ignore_views.txt"
    sql='SELECT TABLE_NAME AS viewname FROM information_schema.`TABLES` WHERE TABLE_TYPE LIKE "VIEW" AND TABLE_SCHEMA LIKE "'$DB_SOURCE_NAME'";'
    mysql -N -h${DB_SOURCE_HOST} -u${DB_SOURCE_USER} -p${DB_SOURCE_PASS} ${DB_SOURCE_NAME} -e "$sql" > $IGNORE_VIEWS_FILE
    echo $IGNORE_VIEWS_FILE
}

function exportSchema {
    printf "\n"
    echo "Exporting Schema..."

    DUMPFILE_NAME="1_schema.sql"
    DUMPFILE_PATH="${TARGETDIR_DUMP_FOLDER}/${DUMPFILE_NAME}"

    IGNORE_TABLES=$(getIgnoreTableList bin/ignore_schema_tables.txt)

    IGNORE_VIEWS_FILE=$(generateIgnoreViewsFile)
    IGNORE_VIEWS=$(getIgnoreTableList $IGNORE_VIEWS_FILE)

    echo 'SET FOREIGN_KEY_CHECKS=0; SET UNIQUE_CHECKS=0; ' > $DUMPFILE_PATH
    # --ignore-table=mysql.event <- This is used to exclude events
    mysqldump --no-data --skip-triggers --compress --compact --skip-opt --create-options --ignore-table=mysql.events -h${DB_SOURCE_HOST} -u${DB_SOURCE_USER} -p${DB_SOURCE_PASS} ${DB_SOURCE_NAME} ${IGNORE_TABLES} ${IGNORE_VIEWS} | sed -r 's/DEFINER=`[^`]+`@`[^`]+`//g' | sed -r "s/\`$DB_SOURCE_NAME\`.//g" | sed -r 's/SQL SECURITY DEFINER//g' >> $DUMPFILE_PATH
    echo 'SET FOREIGN_KEY_CHECKS=1; SET UNIQUE_CHECKS=1; ' >> $DUMPFILE_PATH
}

function exportFunctionsAndStoredProcedures {
    printf "\n"
    echo "Exporting Functions and Stored Procedures..."

    DUMPFILE_NAME="2_spfunc.sql"
    DUMPFILE_PATH="${TARGETDIR_DUMP_FOLDER}/${DUMPFILE_NAME}"

    echo 'SET FOREIGN_KEY_CHECKS=0; SET UNIQUE_CHECKS=0; ' > $DUMPFILE_PATH
    mysqldump --routines --skip-triggers --no-create-info --no-data --no-create-db --skip-opt --ignore-table=mysql.events -h${DB_SOURCE_HOST} -u${DB_SOURCE_USER} -p${DB_SOURCE_PASS} ${DB_SOURCE_NAME} | sed -r 's/DEFINER=`[^`]+`@`[^`]+`//g' | sed -r "s/\`$DB_SOURCE_NAME\`.//g" | sed -r 's/SQL SECURITY DEFINER//g' >> $DUMPFILE_PATH
    echo 'SET FOREIGN_KEY_CHECKS=1; SET UNIQUE_CHECKS=1; ' >> $DUMPFILE_PATH
}

function exportData {
    printf "\n"
    echo "Exporting Data..."

    DUMPFILE_NAME="3_data.sql"
    DUMPFILE_PATH="${TARGETDIR_DUMP_FOLDER}/${DUMPFILE_NAME}"

    IGNORE_TABLES=$(getIgnoreTableList bin/ignore_data_tables.txt)
    echo 'SET FOREIGN_KEY_CHECKS=0; SET UNIQUE_CHECKS=0; ' > $DUMPFILE_PATH
    mysqldump --quick --single-transaction --compress --compact --no-create-info --skip-triggers --ignore-table=mysql.events -h${DB_SOURCE_HOST} -u${DB_SOURCE_USER} -p${DB_SOURCE_PASS} ${DB_SOURCE_NAME} ${IGNORE_TABLES} | sed -r 's/DEFINER=`[^`]+`@`[^`]+`//g' | sed -r "s/\`$DB_SOURCE_NAME\`.//g" | sed -r 's/SQL SECURITY DEFINER//g' >> $DUMPFILE_PATH
    echo 'SET FOREIGN_KEY_CHECKS=1; SET UNIQUE_CHECKS=1; ' >> $DUMPFILE_PATH
}

function exportTriggers {
    printf "\n"
    echo "Exporting Triggers..."

    DUMPFILE_NAME="4_triggers.sql"
    DUMPFILE_PATH="${TARGETDIR_DUMP_FOLDER}/${DUMPFILE_NAME}"

    echo 'SET FOREIGN_KEY_CHECKS=0; SET UNIQUE_CHECKS=0; ' > $DUMPFILE_PATH
    mysqldump --triggers --no-create-info --no-data --no-create-db --skip-opt --ignore-table=mysql.events -h${DB_SOURCE_HOST} -u${DB_SOURCE_USER} -p${DB_SOURCE_PASS} ${DB_SOURCE_NAME} | sed -r 's/DEFINER=`[^`]+`@`[^`]+`//g' | sed -r "s/\`$DB_SOURCE_NAME\`.//g" | sed -r 's/SQL SECURITY DEFINER//g' >> $DUMPFILE_PATH
    echo 'SET FOREIGN_KEY_CHECKS=1; SET UNIQUE_CHECKS=1; ' >> $DUMPFILE_PATH
}

function exportViews {
    printf "\n"
    echo "Exporting Views..."

    DUMPFILE_NAME="5_views.sql"
    DUMPFILE_PATH="${TARGETDIR_DUMP_FOLDER}/${DUMPFILE_NAME}"

    echo 'SET FOREIGN_KEY_CHECKS=0; SET UNIQUE_CHECKS=0; ' > $DUMPFILE_PATH
    mysql -h${DB_SOURCE_HOST} -u${DB_SOURCE_USER} -p${DB_SOURCE_PASS} --skip-column-names --batch -e "SELECT CONCAT('DROP TABLE IF EXISTS ', TABLE_SCHEMA, '.', TABLE_NAME, '; CREATE OR REPLACE VIEW ', TABLE_SCHEMA, '.', TABLE_NAME, ' AS ', VIEW_DEFINITION, '; ') table_name from information_schema.views WHERE TABLE_SCHEMA LIKE '$DB_SOURCE_NAME'" | sed -r 's/DEFINER=`[^`]+`@`[^`]+`//g' | sed -r "s/\`$DB_SOURCE_NAME\`.//g" | sed -r "s/$DB_SOURCE_NAME.//g"  | sed -r 's,\\\\,\\,g' | sed -r 's/SQL SECURITY DEFINER//g' >> $DUMPFILE_PATH
    echo 'SET FOREIGN_KEY_CHECKS=1; SET UNIQUE_CHECKS=1; ' >> $DUMPFILE_PATH
}

function emailExportComplete {
    php "cron.email.php" to=$NOTIFY_EMAIL_ADDRESS h=$DB_SOURCE_HOST u=$DB_SOURCE_USER n=$DB_SOURCE_NAME diff=$diff result=success reason="Successfully exported database"
}

function enforceMaxDumps {


    if [ -f "${TARGETDIR}/${DUMP_FOLDER_NAME}/export.log" ]; then

        if [ "$MAX_DUMPS" -gt "0" ]; then
            echo "Enforce maximum dumps of $MAX_DUMPS"

            IFS=$'\n' read -d '' -r -a DUMPS < ${TARGETDIR}/${DUMP_FOLDER_NAME}/export.log

            COUNTER=0
            for (( idx=${#DUMPS[@]}-1 ; idx>=0 ; idx-- )) ; do
                let COUNTER=(COUNTER+1)

                if [ "$COUNTER" -gt "$MAX_DUMPS" ]; then
                    if [ -e "${DUMPS[idx]}" ]; then
                        echo "  Deleted ${DUMPS[idx]}"
                        rm -rf ${DUMPS[idx]}
                    fi
                fi
            done
        fi

    fi

}

function exportFULL {
    exportSchema
    exportFunctionsAndStoredProcedures
    exportTriggers
    exportViews
    exportData
    compressAndRemoveFolder
    enforceMaxDumps
    emailExportComplete
}

TARGETDIR="$(pwd)"

doCronExport

cd $TARGETDIR

# exit
