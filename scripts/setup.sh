#!/usr/bin/env bash
# Checks out the three ArchSpec builds of the report into vendor/archspec/.
# Set ARCHSPEC_REPO to use a local clone instead of GitHub.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
repo=${ARCHSPEC_REPO:-https://github.com/crmne/archspec.git}
dir=$root/vendor/archspec
mkdir -p "$dir"
[ -d "$dir/repo" ] || git clone --quiet "$repo" "$dir/repo"
git -C "$dir/repo" fetch --quiet origin master pull/36/head pull/37/head 2>/dev/null ||
  git -C "$dir/repo" fetch --quiet origin
checkout() { rm -rf "$dir/$1"; git -C "$dir/repo" worktree prune; git -C "$dir/repo" worktree add --quiet --detach "$dir/$1" "$2"; }
checkout master 207381ee190fdecacf359b94a61d74183560a87e # master
checkout pr36 83170319d9b6f256e78ad0bbd6ed151057c96ec1   # PR #36 (ERB support), then the local fix
git -C "$dir/pr36" apply "$root/patches/erb-partial-script.patch"
checkout pr37 2110c4a99a94cd7cda0c5e1bf00cc4de56f5f0c1   # PR #37 (concern performance)
gem list -i archspec -v 1.1.0 > /dev/null || gem install --silent archspec -v 1.1.0
for app in modules_app packs_app; do (cd "$root/$app" && bundle install --quiet); done
echo "ArchSpec builds are in $dir: master, pr36, pr37"
