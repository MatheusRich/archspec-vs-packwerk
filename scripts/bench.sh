#!/usr/bin/env bash
# Like-for-like benchmark: the same dependency and privacy rules in every tool.
# Prints the median of 3 wall-clock runs per cell. Raw times go to results/bench.raw.
# usage: PKS=path/to/pks scripts/bench.sh | tee results/bench.txt
root=$(cd "$(dirname "$0")/.." && pwd)
PKS=${PKS:-pks}
MASTER=$root/vendor/archspec/master
PR37=$root/vendor/archspec/pr37
raw=$root/results/bench.raw; : > "$raw"
apps="b_5_1000:5:1000 b_8_2500:8:2500 b_8_5000:8:5000 b_15_5000:15:5000 b_40_5000:40:5000"
for spec in $apps; do
  IFS=: read -r d packs files <<< "$spec"
  [ -d "$root/bench/$d" ] || ruby "$root/scripts/gen_bench.rb" "$root/bench/$d" "$packs" "$files"
done
t() { local TIMEFORMAT=%R; { time "$@" >/dev/null 2>&1; } 2>&1; }
med() { local label=$1; shift; local ts=(); for i in 1 2 3; do ts+=($(t "$@")); done; echo "$label ${ts[*]}" >> "$raw"; printf '%s\n' "${ts[@]}" | sort -n | sed -n 2p; }
pw_config() { printf 'require:\n  - packwerk-extensions\n%s' "$1" > packwerk.yml; }
printf "%-10s %6s %8s %8s %10s %13s %10s\n" app files master pr37 packwerk "packwerk+cache" pks
for d in b_5_1000 b_8_2500 b_8_5000 b_15_5000 b_40_5000; do
  cd "$root/bench/$d"
  m=$(med "$d master" ruby -I$MASTER/lib $MASTER/exe/archspec check)
  p=$(med "$d pr37" ruby -I$PR37/lib $PR37/exe/archspec check)
  pw_config ""; rm -rf tmp/cache/packwerk
  k=$(med "$d packwerk" bundle exec packwerk check)
  pw_config $'cache: true\n'; bundle exec packwerk check >/dev/null 2>&1
  kc=$(med "$d packwerk+cache" bundle exec packwerk check)
  s=$(med "$d pks" $PKS --no-cache check)
  pw_config ""
  printf "%-10s %6s %7ss %7ss %9ss %12ss %9ss\n" $d $(find packs -name '*.rb' | wc -l | tr -d ' ') $m $p $k $kc $s
  cd "$root"
done
echo
echo "One-file check (packs/pack5/app/models/pack5/thing25.rb):"
for d in b_8_5000 b_40_5000; do
  cd "$root/bench/$d"; f=packs/pack5/app/models/pack5/thing25.rb
  m=$(med "$d one-file master" ruby -I$MASTER/lib $MASTER/exe/archspec check $f)
  p=$(med "$d one-file pr37" ruby -I$PR37/lib $PR37/exe/archspec check $f)
  pw_config ""; k=$(med "$d one-file packwerk" bundle exec packwerk check $f)
  pw_config $'cache: true\n'; bundle exec packwerk check >/dev/null 2>&1; kc=$(med "$d one-file packwerk+cache" bundle exec packwerk check $f)
  s=$(med "$d one-file pks" $PKS --no-cache check $f)
  pw_config ""
  printf "%-10s master=%ss pr37=%ss packwerk=%ss packwerk+cache=%ss pks=%ss\n" $d $m $p $k $kc $s
  cd "$root"
done
