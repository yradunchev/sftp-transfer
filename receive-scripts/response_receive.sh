#!/bin/bash

# import generic functions for receipt and send processing
source ./response_gen_functions.sh

# ========================================================
# Change the following configuration according to your needs
# ========================================================
INBOX=/home/response/home/response/inbox
LOGFILE=`date '+%Y%m%d_%H%M%S'`
LOCALDIR=/home/cl/scripts

# ========================================================
# DO NOT CHANGE anything below this line
# ========================================================

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

LOGDIR=$LOCALDIR/log
AVAILABLEDIR=$LOCALDIR/available

exec > $LOGDIR/$LOGFILE 2>&1

# ========================================================
# PROGRAM start
# ========================================================

START=`date '+%H:%M:%S'`

echo "Starting script @ $START"
echo "Processing files in $INBOX"

script_ret_val=0

# Find all control files in inbox
for file in `find $INBOX -type f -name control_*`
do
	CONTROL_FILE=`basename "$file"`
	DATA_FILE=${CONTROL_FILE#control_}

	mv "$INBOX/$DATA_FILE" "$AVAILABLEDIR/$DATA_FILE"
	check_error $? "Could not move $INBOX/$DATA_FILE to $AVAILABLEDIR/$DATA_FILE"
	ret_val=$?
	if [ "$ret_val" -ne "0" ]; then
		script_ret_val=1	
	fi

	rm -f "$INBOX/$CONTROL_FILE"
	check_error $? "Could not remove control file. This is very likely a permission problem."
	ret_val=$?
	if [ "$ret_val" -ne "0" ]; then
		script_ret_val=1
	fi

done

END=`date '+%H:%M:%S'`
echo "Script exited @ $END with retval: ${script_ret_val}"

exit $script_ret_val

