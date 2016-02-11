#!/usr/bin/env bash
if [ "$#" -eq  "0" ]; then
    echo "No table name supplied"
    exit 0
fi

if [ "$#" -lt  "2" ]; then
    echo "Script Usage: ./table_compare.sh <table_name> <migration_file_name>"
    exit 0
fi

# get table name
TABLE_NAME=$1

# get migration file name
MIGRATION_NAME=$2

# get current time
CURRENT_TIME=$(date +"%Y%m%d%I%M%S")

# migration file ext
MIGRATION_EXT=".sql"

# create migration file name
MIGRATION_FILENAME="$CURRENT_TIME""_""$MIGRATION_NAME""$MIGRATION_EXT"

# migration path
MIGRATION_PATH="output/$MIGRATION_FILENAME"

# Your public key file
PUBLIC_KEY_FILE="/Users/<your_username>/.ssh/id_rsa"

# Dev DB
DEV_DB_NAME=""

# Dev DB User
DEV_DB_USER="root"

<<COMMMENT1
Dev mysql password for root. Use root account unless
the user has full privleges on that db
COMMMENT1
DEV_DB_PASS=""

# Dev User
DEV_SSH_USER=""

# Dev Host
DEV_SSH_HOST=""

# Local DB
VAGRANT_DB_NAME=""

# Local DB User
VAGRANT_DB_USER="root"

<<COMMENT2
Vagrant mysql password for root. Use root account unless
the user has full privleges on that db
COMMENT2
VAGRANT_DB_PASS=""

# Local User
VAGRANT_SSH_USER="vagrant"

# Local Port
VAGRANT_SSH_PORT="2222"

# Assign local port for Dev mysql
LOCAL_PORT_4_DEV="9307"

# Assign local port for Vagrant mysql
LOCAL_PORT_4_VAGRANT="9308"

# Localhost
LOCAL_SSH_HOST="127.0.0.1"

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
             "$DEV_SSH_USER"@"$DEV_SSH_HOST" -i "$PUBLIC_KEY_FILE"

# Forward Vagrant mysql to local port "$LOCAL_PORT_4_VAGRANT"
ssh -f -N -L "$LOCAL_PORT_4_VAGRANT":"$LOCAL_SSH_HOST":"$DEFAULT_MYSQL_PORT" \
    -p "$VAGRANT_SSH_PORT" "$VAGRANT_SSH_USER"@"$LOCAL_SSH_HOST" -i "$PUBLIC_KEY_FILE"

# Table Compare against Dev
OUTPUT=`mysqldiff \
        --server1="$DEV_DB_USER":"$DEV_DB_PASS"@"$LOCAL_SSH_HOST":"$LOCAL_PORT_4_DEV" \
        --server2="$VAGRANT_DB_USER":"$VAGRANT_DB_PASS"@"$LOCAL_SSH_HOST":"$LOCAL_PORT_4_VAGRANT" \
        --difftype=sql "$DEV_DB_NAME"".""$TABLE_NAME":"$VAGRANT_DB_NAME"".""$TABLE_NAME" \
        --changes-for=server1`

if [[ $OUTPUT == *"does not exist"* ]]; then
    mysqldump \
        -u"$VAGRANT_DB_USER" \
        -p"$VAGRANT_DB_PASS" \
        --host="$LOCAL_SSH_HOST" \
        --port="$LOCAL_PORT_4_VAGRANT" "$VAGRANT_DB_NAME" "$TABLE_NAME" >> "$MIGRATION_PATH"
elif [[ $OUTPUT == *"Success"* ]]; then
    echo "No difference found for <$TABLE_NAME> table in $DEV_DB_NAME."
else
    echo "$OUTPUT" > "$MIGRATION_PATH"
fi

exit 0