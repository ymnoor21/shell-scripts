#!/usr/bin/env bash

# setup environment name
ENVIRONMENT1="dev"
ENVIRONMENT2="vagrant"

# get current time
CURRENT_TIME=$(date +"%Y%m%d%I%M%S")

# create file
FILENAME="output/""$CURRENT_TIME""_db_compare_""$ENVIRONMENT1""_vs_""$ENVIRONMENT2"".sql"

if [ -f "$FILENAME" ]
then
    rm "$FILENAME"
fi

# Public key file
PUBLIC_KEY_FILE="/Users/<your_username>/.ssh/id_rsa"

# Dev SSH User
DEV_SSH_USER=""

# Dev SSH Host
DEV_SSH_HOST=""

# Dev Mysql DB Name
DEV_DB_NAME=""

# Dev Mysql User
DEV_DB_USER=""

<<COMMENT1
Dev mysql password for root. Use root account unless
the user has full privleges on that db
COMMENT1
DEV_DB_PASS=""

# Vagrant SSH User
VAGRANT_SSH_USER="vagrant"

# Vagrant SSH port
VAGRANT_SSH_PORT="2222"

# Dev Mysql DB Name
VAGRANT_DB_NAME=""

# Dev Mysql User
VAGRANT_DB_USER="root"

<<COMMENT2
Vagrant mysql password for root. Use root account unless
the user has full privleges on that db
COMMENT2
VAGRANT_DB_PASS=""

# Local port for Dev Mysql
LOCAL_PORT_4_DEV="9307"

# Local port for Vagrant Mysql
LOCAL_PORT_4_VAGRANT="9308"

# Local hostname
LOCAL_HOST="127.0.0.1"

# Default MySQL Port
DEFAULT_MYSQL_PORT="3306"

# get process id of Dev's local port
PORT1=`lsof -i:"$LOCAL_PORT_4_DEV" -t`

# get process id of Vagrant's local port
PORT2=`lsof -i:"$LOCAL_PORT_4_VAGRANT" -t`

<<COMMENT3
check if "$LOCAL_PORT_4_DEV" is already in use,
if so - kill the process
COMMENT3
if [ ! -z "$PORT1" ]; then
    kill "$PORT1"
fi

<<COMMENT4
check if local port "$LOCAL_PORT_4_VAGRANT" is already in use,
if so - kill the process
COMMENT4
if [ ! -z "$PORT2" ]; then
    kill "$PORT2"
fi

# Forward Dev mysql to local port "$LOCAL_PORT_4_DEV"
ssh -f -N -L "$LOCAL_PORT_4_DEV":"$LOCAL_HOST":"$DEFAULT_MYSQL_PORT" \
             "$DEV_SSH_USER"@"$DEV_SSH_HOST" -i "$PUBLIC_KEY_FILE"

# Forward Vagrant mysql to local port "$LOCAL_PORT_4_VAGRANT"
ssh -f -N -L "$LOCAL_PORT_4_VAGRANT":"$LOCAL_HOST":"$DEFAULT_MYSQL_PORT" \
    -p "$VAGRANT_SSH_PORT" "$VAGRANT_SSH_USER"@"$LOCAL_HOST" -i "$PUBLIC_KEY_FILE"

# DB Compare against Dev
mysqldbcompare \
    --server1="$DEV_DB_USER":"$DEV_DB_PASS"@"$LOCAL_HOST":"$LOCAL_PORT_4_DEV" \
    --server2="$VAGRANT_DB_USER":"$VAGRANT_DB_PASS"@"$LOCAL_HOST":"$LOCAL_PORT_4_VAGRANT" \
    --difftype=sql "$DEV_DB_NAME":"$VAGRANT_DB_NAME" \
    --changes-for=server1 \
    --run-all-tests \
    --skip-data-check >> "$FILENAME"
