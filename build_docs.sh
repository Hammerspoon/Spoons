#!/bin/bash

mkdir -p .docs_tmp
../hammerspoon/scripts/docs/bin/build_docs.py -e ..//hammerspoon/scripts/docs/templates/ -o .docs_tmp -j -t -n Source
cp ..//hammerspoon/scripts/docs/templates/{docs.css,jquery.js} .docs_tmp/html/
mv .docs_tmp/html/* docs/
