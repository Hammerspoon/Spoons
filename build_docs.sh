#!/bin/bash

mkdir -p Docs
../hammerspoon/scripts/docs/bin/build_docs.py -e ..//hammerspoon/scripts/docs/templates/ -o Docs -j -t -n Source
