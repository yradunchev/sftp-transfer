#!/bin/bash

# $LastChangedDate$
# $Revision$

# import generic functions for receipt and send processing
source ./transfer_gen_functions.sh

# ========================================================
# Change the following configuration according to your needs
# ========================================================
USER=bob
HOST=localhost
LOCALDIR=/home/alice
REMOTEDIR=inbox
LOGFILE=`date '+%Y%m%d_%H%M%S'`

# ========================================================
# DO NOT CHANGE anything below this line
# ========================================================

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

OUTBOX=$LOCALDIR/outbox
LOGDIR=$LOCALDIR/log
PROCDIR=$LOCALDIR/processing
CONTROLDIR=$LOCALDIR/control
ERRORDIR=$LOCALDIR/error
ARCHIVEDIR=$LOCALDIR/archive

exec > $LOGDIR/$LOGFILE 2>&1

# ========================================================
# PROGRAM start
# ========================================================

START=`date '+%H:%M:%S'`

echo "Starting script @ $START"
echo "Processing files in $OUTBOX"

# empty control directory
rm -f $LOCALDIR/control/*

# check what is to be sent. Set up control file and command file for sftp
for file in `find $OUTBOX -type f`
do
	FILENAME=`basename "$file"`
	mv -f $file $PROCDIR/$FILENAME
	touch $CONTROLDIR/control_$FILENAME
	cat > $CONTROLDIR/commands_$FILENAME << UNTIL_THIS_TOKEN
cd $REMOTEDIR
put $PROCDIR/$FILENAME
put $CONTROLDIR/control_$FILENAME
UNTIL_THIS_TOKEN

done

script_ret_val=0

# Now process each file and ensure it was sent ok.
for file in `find $PROCDIR -type f`
do
	lsof -w > /dev/null 2>&1 $file
	RETVAL=$?

	if [ "${RETVAL}" -eq "0" ]; then
		# file is in use, so don't copy yet.
		echo "File $file is still in use, deferring the transfer for that file."
		continue
	fi

	FILENAME=`basename "$file"`
	sftp -b $CONTROLDIR/commands_$FILENAME $USER@$HOST
	check_error $? "Failed SFTP operation for $FILENAME"

	ret_val=$?
	if [ "${ret_val}" -ne "0" ]; then
		# Something went wrong with the SFTP operation
		# Move processing file to error dir.
		echo "moving $PROCDIR/$FILENAME to $ERRORDIR/" 
		mv -f "$PROCDIR/$FILENAME" "$ERRORDIR/"

		# Indicate there were errors
		script_ret_val=1
	else
		# File successfully transferred. Move file to archive dir
		echo "removing $PROCDIR/$FILENAME"
		mv -f "$PROCDIR/$FILENAME" "$ARCHIVEDIR/"
	fi

	# Remove control files
	rm -f "$CONTROLDIR/control_$FILENAME"
	rm -f "$CONTROLDIR/commands_$FILENAME"

done

END=`date '+%H:%M:%S'`
echo "Script exited @ $END with retval: ${script_ret_val}"

exit $script_ret_val


