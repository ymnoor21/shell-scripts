#!/usr/bin/env bash
if [ "$#" -eq  "0" ]; then
    echo "No table name supplied"
    echo "Script Usage: ./table_compare.sh <table_name> [migration_file_name]"
    exit 0
fi

# get table name
TABLE_NAME=$1

# get migration file name
MIGRATION_NAME=$2

if [ -z "$MIGRATION_NAME" ]; then
    MIGRATION_NAME="$TABLE_NAME"
fi

# get current time
CURRENT_TIME=$(date + "%Y%m%d%I%M%S")

# migration file ext
MIGRATION_EXT=".sql"

# create migration file name
MIGRATION_FILENAME="$CURRENT_TIME""_""$MIGRATION_NAME""$MIGRATION_EXT"

# migration path
MIGRATION_PATH="migrations/$MIGRATION_FILENAME"

# Your key file
KEY_FILE="/Users/<user_name>/.ssh/id_rsa"

# mysqldump file
MYSQL_DUMP_FILE="mysqldump.txt"

# Dev DB
DEV_DB_NAME="your_dev_db"

# Dev DB User
DEV_DB_USER="root"

<<COMMENT1
Dev mysql password for root. Use root account
unless the user has full privileges on that db
COMMENT1
DEV_DB_PASS="your_dev_db_pass"

# Dev User
DEV_SSH_USER="deploy"

# Dev Host
DEV_SSH_HOST="dev.myapp.com"

# Local DB
LOCAL_DB_NAME="your_local_db"

# Local DB User
LOCAL_DB_USER="root"

<<COMMENT2
Vagrant mysql password for root. Use root account
unless the user has full privileges on that db
COMMENT2
LOCAL_DB_PASS='your_local_db_pass'

# Localhost
LOCAL_SSH_HOST="127.0.0.1"

# Local User
LOCAL_SSH_USER="vagrant"

# Local Port / Vagrant port
LOCAL_SSH_PORT="2222"

# Assign local port for Dev mysql
LOCAL_PORT_4_DEV="9307"

# Assign local port for Vagrant mysql
LOCAL_PORT_4_VAGRANT="9308"

# Default MySQL PORT
DEFAULT_MYSQL_PORT="3306"

# get process id of local port for dev mysql
PORT1=`lsof -i:"$LOCAL_PORT_4_DEV" -t`

# get process id of local port for vagrant mysql
PORT2=`lsof -i:"$LOCAL_PORT_4_VAGRANT" -t`

<<COMMENT3
check if "$LOCAL_PORT_4_DEV" is already in use,
if so - kill the process which is using the port
COMMENT3
if [ ! -z "$PORT1" ]; then
    kill "$PORT1"
fi

<<COMMENT4
check if "$LOCAL_PORT_4_VAGRANT" is already in use,
if so - kill the process which is using the port
COMMENT4
if [ ! -z "$PORT2" ]; then
    kill "$PORT2"
fi

# Forward Dev mysql to local port "$LOCAL_PORT_4_DEV"
ssh -f -N -L "$LOCAL_PORT_4_DEV":"$LOCAL_SSH_HOST":"$DEFAULT_MYSQL_PORT" \
    "$DEV_SSH_USER"@"$DEV_SSH_HOST" -i "$KEY_FILE"

# Forward Vagrant mysql to local port "$LOCAL_PORT_4_VAGRANT"
ssh -f -N -L "$LOCAL_PORT_4_VAGRANT":"$LOCAL_SSH_HOST":"$DEFAULT_MYSQL_PORT" \
    -p "$LOCAL_SSH_PORT" "$LOCAL_SSH_USER"@"$LOCAL_SSH_HOST" -i "$KEY_FILE"

# Table Compare against Dev
OUTPUT=`mysqldiff \
        --server1="$DEV_DB_USER":"$DEV_DB_PASS"@"$LOCAL_SSH_HOST":"$LOCAL_PORT_4_DEV" \
        --server2="$LOCAL_DB_USER":"$LOCAL_DB_PASS"@"$LOCAL_SSH_HOST":"$LOCAL_PORT_4_VAGRANT" \
        --difftype=sql "$DEV_DB_NAME"".""$TABLE_NAME":"$LOCAL_DB_NAME"".""$TABLE_NAME" \
        --changes-for=server1`

if [[ $OUTPUT == *"does not exist"* ]]; then
    DUMP_RESULT=`mysqldump \
                    -u"$LOCAL_DB_USER" \
                    -p"$LOCAL_DB_PASS" \
                    --host="$LOCAL_SSH_HOST" \
                    --port="$LOCAL_PORT_4_VAGRANT" "$LOCAL_DB_NAME" \
                    2>"$MYSQL_DUMP_FILE" \
                    "$TABLE_NAME" >> "$MIGRATION_PATH"`

    DUMP_RESULT_CONTENTS=`sed -n "/Couldn\'t find table/p" "$MYSQL_DUMP_FILE"`

    if [[ $DUMP_RESULT_CONTENTS == *"Couldn't find table: \"$TABLE_NAME\""* ]]; then
        if [ -f "$MYSQL_DUMP_FILE" ]; then
            rm "$MYSQL_DUMP_FILE"
        fi

        if [ -f "$MIGRATION_PATH" ]; then
            rm "$MIGRATION_PATH"
        fi

        echo "Couldn't find <$TABLE_NAME> table in $LOCAL_DB_NAME ($LOCAL_SSH_HOST)."
    fi
elif [[ $OUTPUT == *"Success"* ]]; then
    echo "No difference found for <$TABLE_NAME> table in $DEV_DB_NAME ($DEV_SSH_HOST)."
else
    echo "$OUTPUT" > "$MIGRATION_PATH"
fi

if [ -f "$MIGRATION_PATH" ]; then
    # remove dev dbname, and delete lines which contains any of these:
    # --, @, #, /*!, empty line, Compare failed
    FILE_CONTENTS=`sed 's/\`'"$DEV_DB_NAME"'\`\.//g; \
                        /^\s*--/ d; \
                        /^\s*[@#]/ d; \
                        s/.*\/\*\!.*//; \
                        /^\s*$/d; \
                        s/.*Compare\ failed.*//' "$MIGRATION_PATH"`
    echo "$FILE_CONTENTS" > "$MIGRATION_PATH"
    echo "Generated a migration file here: $MIGRATION_PATH"
fi

exit 0