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

sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/g" npm_package/package.json

git commit -m "chore(release): v$VERSION"

git tag "v$VERSION"

git push origin "v$VERSION"

git push

