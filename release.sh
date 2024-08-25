#!/bin/bash

set -eou pipefail

VERSION="$1"
if ! git diff --quiet; then
  echo "Error: There are unstaged changes in the repository."
  exit 1
fi

sed -i '' "s/(version [^)]*)/(version $VERSION)/g" dune-project
dune build 

sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/g" package.json
npm install

