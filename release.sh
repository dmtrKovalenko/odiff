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

if [[ "$DRY_RUN" == "false" ]] && ! git diff --quiet; then
  echo "Error: There are unstaged changes in the repository."
  exit 1
fi

# stamps the version on build.zig.zon and every npm package + cross-package dependency pin
node scripts/set-npm-version.js "$VERSION"
zig build --release=fast
npm install --ignore-scripts


if [ "$DRY_RUN" == true ]; then
  echo "Dry run, not committing or tagging"
else
  git add --all
  git commit -m "chore(release): v$VERSION"
  git tag "v$VERSION"
  git push origin "v$VERSION"
  git push
fi

