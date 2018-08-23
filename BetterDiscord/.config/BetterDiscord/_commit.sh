#!/usr/bin/env sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

git add plugins/ themes/
git commit -m "$(date -Iseconds)"
