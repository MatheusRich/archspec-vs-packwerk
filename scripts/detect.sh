#!/usr/bin/env bash
# Runs every tool on the two fixture apps and writes the results to results/.
# Run scripts/setup.sh first.
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
out=$root/results
v110=$(dirname "$(gem contents archspec -v 1.1.0 | grep '/lib/archspec.rb$')")
archspec() { local lib=$1; shift; ruby -I"$lib" "$lib/../exe/archspec" "$@"; }
# The progress dots and the time change on every run, so they are removed.
packwerk() { bundle exec packwerk check 2>&1 | sed -E $'s/\x1b\\[[0-9;]*m//g' | grep -Ev '^[.E]+$|^📦 Finished in'; }
# Writes a variant of Archspec.rb. The variant must stay in the app, because
# the folder of the config file is the project root.
variant() { local name=$1 script=$2; sed -E "$script" Archspec.rb > "Archspec.$name.rb"; }

cd "$root/modules_app"
pr36=$root/vendor/archspec/pr36/lib
# 1.1.0 has no facts file, so it gets the same rules without the facts line.
variant nofacts '/^facts/d'
archspec "$v110" check --config Archspec.nofacts.rb --format json > "$out/modules_archspec_1.1.0.json"
for build in master pr36; do
  lib=$root/vendor/archspec/$build/lib
  ARCHSPEC_PATH=../vendor/archspec/$build bundle exec ruby -I"$lib" "$lib/../exe/archspec" reflect > /dev/null
  archspec "$lib" check --format json > "$out/modules_archspec_$build.json"
done
# The same rules, with the tests and rake tasks added to the sources (N1, N2).
variant globs 's|^facts .*|facts "archspec_facts_globs"\nsource "app/**/*.rb", "lib/**/*.rb", "test/**/*.rb", "lib/tasks/**/*.rake"|'
bundle exec ruby -I"$pr36" "$pr36/../exe/archspec" reflect --config Archspec.globs.rb > /dev/null
archspec "$pr36" check --config Archspec.globs.rb --format json > "$out/modules_archspec_pr36_globs.json"
# The public API as an exact constant instead of a namespace (N3).
variant constants 's|public_api namespace:|public_api constants:|'
archspec "$pr36" check --config Archspec.constants.rb --format json > "$out/modules_archspec_pr36_constants.json"
rm Archspec.nofacts.rb Archspec.globs.rb Archspec.constants.rb
packwerk > "$out/modules_packwerk.txt"

cd "$root/packs_app"
archspec "$pr36" check --format json > "$out/packs_archspec_pr36.json"
packwerk > "$out/packs_packwerk.txt"

cd "$root"
for app in modules packs; do
  for json in "$out/${app}"_archspec_*.json; do
    ruby scripts/report_archspec.rb "${app}_app" "$json" > "${json%.json}.txt"
  done
done
wc -l "$out"/*.txt
