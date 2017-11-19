#!/usr/bin/env sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

git add plugins/ themes/
git add _update.sh _commit.sh
git commit -m "$(date -Iseconds)"
