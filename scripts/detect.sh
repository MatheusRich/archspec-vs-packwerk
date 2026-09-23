#!/usr/bin/env bash
# Runs every tool on the two fixture apps and writes the results to results/.
# Run scripts/setup.sh first.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/results
v110=$(dirname "$(gem contents archspec -v 1.1.0 | grep '/lib/archspec.rb$')")
archspec() { local lib=$1; shift; ruby -I"$lib" "$lib/../exe/archspec" "$@"; }

cd "$root/modules_app"
# 1.1.0 has no facts file, so it gets the same rules without the facts line.
# The config file must stay in the app, because its folder is the project root.
grep -v '^facts' Archspec.rb > Archspec.nofacts.rb
archspec "$v110" check --config Archspec.nofacts.rb --format json > "$out/modules_archspec_1.1.0.json"
rm Archspec.nofacts.rb
for build in master pr36; do
  lib=$root/vendor/archspec/$build/lib
  ARCHSPEC_PATH=../vendor/archspec/$build bundle exec ruby -I"$lib" "$lib/../exe/archspec" reflect > /dev/null
  archspec "$lib" check --format json > "$out/modules_archspec_$build.json"
done
bundle exec packwerk check > "$out/modules_packwerk.txt" 2>&1

cd "$root/packs_app"
archspec "$root/vendor/archspec/pr36/lib" check --format json > "$out/packs_archspec_pr36.json"
bundle exec packwerk check > "$out/packs_packwerk.txt" 2>&1

cd "$root"
for app in modules packs; do
  for json in "$out/${app}"_archspec_*.json; do
    ruby scripts/report_archspec.rb "${app}_app" "$json" > "${json%.json}.txt"
  done
done
wc -l "$out"/*.txt
