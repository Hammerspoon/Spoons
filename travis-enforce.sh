#!/bin/bash

set -u

# Enforce some basic things we want, in a Spoon
FAILED=0

pushd Source || exit

# Check that there's a line containing: obj.version = ['"][0-9.]+['"]
echo "Checking for obj.version conformance..."
for spoon in * ; do
    echo -n "  ${spoon}: "
    VERSIONSTR=$(grep -E "obj.version[ ]*=[ ]*['\"][0-9.]+['\"]" "${spoon}/init.lua" | awk '{ print $NF}')
    if [ "${VERSIONSTR}" == "" ]; then
        echo "UNKNOWN"
        FAILED=1
    else
        echo "${VERSIONSTR}"
    fi
done
echo ""

if [ "${FAILED}" != "0" ]; then
    echo "Some preceeding check failed."
    exit 1
fi

echo "ALL CHECKS PASSED."
