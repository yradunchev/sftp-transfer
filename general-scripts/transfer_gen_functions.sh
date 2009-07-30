#!/bin/bash

# $LastChangedDate$
# $Rev$

# Checking for errors function
check_error() {
    if [ "${1}" -ne "0" ]; then
        echo "FAILED - ${2}"
		return 1
    fi
	return 0
}
