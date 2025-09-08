#!/bin/bash

set -eou pipefail

VERSION="$1"
DRY_RUN=false

for arg in "$@"
do
  if [ "$arg" = "--dry-run" ]; then
    DRY_RUN=true
    break
  fi
done

if ! git diff --quiet; then
  echo "Error: There are unstaged changes in the repository."
  exit 1
fi

sed -i '' "s/\.version = \"[^\"]*\"/\.version = \"$VERSION\"/g" build.zig.zon
zig build

sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/g" package.json
npm install

sed -i '' "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/g" npm_package/package.json

if [ "$DRY_RUN" == true ]; then
  echo "Dry run, not committing or tagging"
else
  git add --all
  git commit -m "chore(release): v$VERSION"
  git tag "v$VERSION"
  git push origin "v$VERSION"
  git push
fi

