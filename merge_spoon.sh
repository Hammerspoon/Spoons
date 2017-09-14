#!/bin/bash

if [ "$1" == "" -o "$2" == "" ]; then
    echo "Usage: $0 GITHUB_PR_ID SPOON_NAME"
    echo "(set PR ID to 0 to skip fetching code)"
    exit 1
fi

set -x

PR="$1"
SPOON="$2"

if [ "${PR}" != "0" ]; then
    hub am -3 https://github.com/Hammerspoon/Spoons/pull/${PR}
fi

set -eu

../hammerspoon/scripts/docs/bin/build_docs.py -e ../hammerspoon/scripts/docs/templates/ -o Source/${SPOON}.spoon/ -j -n Source/${SPOON}.spoon/
rm Source/${SPOON}.spoon/docs_index.json
git commit -am "Generate docs for ${SPOON}"
make
git add Spoons/${SPOON}.spoon.zip
git commit -am "Add binary package for ${SPOON}. Closes #${PR}"
./build_docs.sh
git add docs
git commit -am "Update docs"
#git push

