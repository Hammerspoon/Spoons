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
    echo "No Spoons modified, skipping docs rebuild"
    exit 0
fi

git config --global user.email "spoonPRbot@tenshu.net"
git config --global user.name "Spoons GitHub Bot"

while IFS= read -r SPOON ; do
    ./hammerspoon/scripts/docs/bin/build_docs.py -e ./hammerspoon/scripts/docs/templates/ -o Source/${SPOON}.spoon/ -j -n Source/${SPOON}.spoon/
    rm Source/${SPOON}.spoon/docs_index.json
    git add Source/${SPOON}.spoon/docs.json
    git commit -am "Generate docs for ${SPOON}" || true
    rm -f Spoons/${SPOON}.spoon.zip
    make
    git add Spoons/${SPOON}.spoon.zip
    git commit -am "Add binary package for ${SPOON}."
    ./build_docs.sh
    git add docs
    git commit -am "Update docs"
done <<< "${SPOONS}"

