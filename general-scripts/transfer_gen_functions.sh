#!/bin/bash

# $LastChangedDate$
# $Revision$

# Checking for errors function
check_error() {
    if [ "${1}" -ne "0" ]; then
        echo "FAILED - ${2}"
		return 1
    fi
	return 0
}

in_use() {
	lsof -w > /dev/null 2>&1 "${1}"
	if [ $? -gt 0 ]; then
		echo "File ${1} is still in use, deferring the transfer for that file."
		return 1
	fi
		return 0
}
