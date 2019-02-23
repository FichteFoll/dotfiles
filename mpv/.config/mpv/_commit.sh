#!/usr/bin/env sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

git add scripts/ shaders/ .gitignore
git commit -m "$(date -Iseconds)"
