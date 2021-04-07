#!/bin/bash

if [ "$GITHUB_ACTIONS" != "true" ]; then
    echo "This script should only be run as part of a GitHub Action"
    exit 1
fi

set -x
set -eu

# Find the Spoons that have been modified
SPOONS=$(cat "${HOME}/files.json" | jq -r -c '.[] | select(contains(".lua"))' | sed -e 's#^Source/\(.*\).spoon/.*#\1#' | sort | uniq)

if [ "${SPOONS}" == "" ]; then
    echo "No Spoons modified, skipping doc linting"
    exit 0
fi

mkdir -p annotations

while IFS= read -r SPOON ; do
    /usr/bin/python3 ./hammerspoon/scripts/docs/bin/build_docs.py -l -o annotations/ -n Source/${SPOON}.spoon/
    mv annotations/annotations.json "annotations/${SPOON}-annotations.json"
done <<< "${SPOONS}"

jq -s '[.[][]]' annotations/*.json >annotations.json
rm -rf annotations/

