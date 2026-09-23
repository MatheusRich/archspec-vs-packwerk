# ArchSpec with namespaced modules as a replacement for Packwerk

This report compares two ways to enforce boundaries between the domains of a Rails app:

- **Namespaced modules with [ArchSpec](https://archspecrb.dev/).** Each domain is a Ruby namespace (`Billing`, `Sales`) inside the standard Rails folders (`app/models/billing/`, `app/controllers/sales/`). ArchSpec checks the boundaries statically.
- **[Packwerk](https://github.com/Shopify/packwerk) with packwerk-extensions.** Each domain is a package directory (`packs/billing/`) with a `package.yml`. The report also measures [pks](https://github.com/alexevanczuk/packs), a Rust implementation of the Packwerk checks that reads the same configuration.

The question is whether the first approach can replace Packwerk: does it catch the same violations, how fast is it, and how well does it fit a normal Rails app?

All results come from runs on 2026-09-23 on one machine. Two adversarial reviews checked a first version of this report. This version includes the corrections that the reviews found and that a rerun confirmed. Where a result is an inference and not a measurement, the text says so.

## Summary

The two approaches catch the same violations. The difference is a trade-off. ArchSpec is easier to live with in the app itself: the code stays in a plain Rails layout. Packwerk is easier in the check workflow: it is faster, it needs one command, and it is mature.

### Detection is equal

With the right configuration, each tool catches 18 of the 20 violations in the test set. Neither tool follows dynamic lookups such as `constantize`. Two ArchSpec capabilities are not released yet: association support is on `master` only, and ERB support is in a draft PR that needs one more fix.

### ArchSpec is better for the app

- **Plain Rails.** A domain is a folder and a namespace in the standard Rails folders. Zeitwerk loads it with the default settings. Generators write to the correct folders (they only ask before they replace an existing namespace file), and `bin/rails test` finds the tests.
- **Configuration.** One `Archspec.rb` file holds all rules. One line declares a domain by namespace across all Rails folders, and the public API can be a namespace. Packwerk needs a `package.yml` in each package directory.
- **More rules.** The ArchSpec presets for Rails (for example, "models must not depend on controllers") work together with the rules for each domain. ArchSpec also checks rules at the class level that Packwerk does not: forbidden method calls, method protocols and naming.
- **Precise locations.** ArchSpec reports the exact line and column, also in ERB. Packwerk reported one ERB violation at `1:1`.

On the packs layout, most Rails tools need extra configuration (packs-rails, a test glob, a move step after generators), and the ArchSpec presets for Rails do not see the pack code.

### Packwerk is better for the check workflow

- **Speed.** Packwerk is faster at every size that was measured. A full check on 5,000 files takes about 1s with Packwerk, 0.2s with pks, and 7s to 18s with ArchSpec. A check of one file takes 0.6s with Packwerk, 0.1s with pks, and 8s to 19s with ArchSpec, because ArchSpec always analyzes the whole project. On 1,000 files, ArchSpec takes 1.3s, so the difference matters most for large apps and for pre-commit hooks.
- **One step.** For association checks, ArchSpec needs `archspec reflect` (an app boot) before `archspec check`, and any change to the source or configuration makes the facts file stale. Packwerk reads associations from the source in one command.
- **Defaults.** Packwerk reads tests, rake tasks and ERB files by default. ArchSpec needs extra `source` and `in:` globs for them.
- **Obsolete todo entries.** Packwerk fails when the todo file lists a violation that no longer exists. ArchSpec needs an open PR for that.
- **Maturity.** Packwerk and its tools have existed for years. ArchSpec is at version 1.1.0 (its first pull request is from 2026-06-24), and one author wrote 89 of its 91 commits.

### Recommendation

For a small or mid-size app, namespaced modules with ArchSpec are a good choice. The layout stays plain Rails, and a full check takes a few seconds: 1.3s on 1,000 files and 3.5s on 2,500 files in the benchmark. The condition is a release that includes association reflection and ERB support. Packwerk or pks is the better tool for a large app that needs fast checks on each commit, or for an app that already uses packs.

## Setup

| Item | Version |
|---|---|
| Ruby | 3.4.6 (macOS, 14 CPUs: 10 performance and 4 efficiency cores) |
| Rails | 8.1.3.1 |
| ArchSpec | 1.1.0 (released), `master` at `207381e`, and `master` with PR #36 plus a local fix (`patches/erb-partial-script.patch`) |
| Packwerk | 3.3.1, with packwerk-extensions 0.3.0 for privacy checks |
| pks | 0.2.40 |
| Herb | 0.10.4 (used by PR #36 to read ERB) |

There are two copies of one small Rails app:

- `modules_app/` uses the modules layout. The `Archspec.rb` declares `billing` and `sales` by namespace, and adds the ERB views with `in:`. `sales` can only use `billing`, `billing` cannot use `sales`, and only the `Billing::Api` namespace is public.
- `packs_app/` uses the Packwerk layout, with the same code moved into `packs/billing/` and `packs/sales/`. `packs/sales` depends on `packs/billing`. `packs/billing` enforces privacy, and its public folder holds `Billing::Api`.

Each fixture file marks its case with a `# CASE Cxx` comment. The author of this report wrote the cases, so they do not prove that either tool is complete.

## Detection

The ArchSpec columns use the modules layout. The Packwerk column uses the packs layout.

| Case | What the code does | ArchSpec 1.1.0 | ArchSpec `master` | `master` + PR #36 + fix | Packwerk |
|---|---|---|---|---|---|
| C01 | Sales uses `Billing::Invoice.where(...)` | ✅ | ✅ | ✅ | ✅ |
| C02 | Sales uses `::Billing::Invoice` | ✅ | ✅ | ✅ | ✅ |
| C03 | `class Refund < Billing::Invoice` | ✅ | ✅ | ✅ | ✅ |
| C04 | `include Billing::Taxable` | ✅ | ✅ | ✅ | ✅ |
| C05, C05b, C05c | `has_many`, `belongs_to` and `has_one` with `class_name: "Billing::Invoice"` | ❌ | ✅ (1) | ✅ (1) | ✅ |
| C07 | `"Billing::Invoice".constantize` | ❌ | ❌ | ❌ | ❌ |
| C08 | `Billing.const_get(:Invoice)` | partial (2) | partial (2) | partial (2) | partial (2) |
| C10 | `rescue Billing::PaymentError` | ✅ | ✅ | ✅ | ✅ |
| C11 | A Sales ERB view uses `Billing::Invoice` | ❌ | ❌ | ✅ | ✅ |
| C11b | A Billing ERB view uses `Sales::Order` | ❌ | ❌ | ✅ | ✅ (3) |
| C12 | A Sales controller uses `Billing::Invoice` | ✅ | ✅ | ✅ | ✅ |
| C18 | `invoices.last.void!` (no constant in the code) | ❌ | ❌ | ❌ | ❌ |
| C19 | Billing uses `Sales::Order` (the wrong direction) | ✅ | ✅ | ✅ | ✅ |
| C21 | `INVOICE = Billing::Invoice` | ✅ | ✅ | ✅ | ✅ |
| C22 | `Billing.charge(order)` on the namespace module | ✅ (4) | ✅ (4) | ✅ (4) | ✅ |
| C25 | `Class.new(Billing::Invoice)` | ✅ | ✅ | ✅ | ✅ |
| N1 | A Sales test uses `Billing::Invoice` | not run | not run | ❌ by default, ✅ with extra globs (5) | ✅ |
| N2 | A Sales rake task uses `Billing::Invoice` | not run | not run | ❌ by default, ✅ with extra globs (5) | ✅ |
| | **Violations caught (C cases: 18, N cases: 2)** | **11 of 18** | **14 of 18** | **16 of 18; 18 of 20 with extra globs** | **18 of 20** |

The test set also has controls that must not be flagged. No tool flagged a control, but not every control proves something in every column:

| Control | What the code does | Result |
|---|---|---|
| C00, C14 | Sales calls the public `Billing::Api` from a model and a job | Not flagged by any tool |
| C05d | `class_name: "Sales::Order"` inside Sales | Not flagged by any tool |
| C11c | A Sales ERB view calls `Billing::Api` | Not flagged. This proves something only for the columns that read ERB |
| N3 | Sales uses `Billing::Api::Result`, a constant nested in the public API | Not flagged by Packwerk or by ArchSpec with `public_api namespace: "Billing::Api"`. ArchSpec with `public_api constants: "Billing::Api"` flags it, because `constants:` matches exact names only |

Notes:

1. `archspec reflect` boots the app and asks Active Record for the association targets. It writes a facts file that `archspec check` reads. See [The facts file](#the-facts-file) for its cost.
2. Both tools see only the reference to the `Billing` module, not the lookup of `Invoice`. The case counts as caught in the totals, but the real private constant goes undetected.
3. Packwerk reports the ERB violation at `1:1`, although the reference is on line 2. ArchSpec reports the exact line and column.
4. ArchSpec flags C08 and C22 because the `Billing` module itself is private in this configuration. On the packs layout with a file glob for `public_api`, ArchSpec does not flag them: `app/public/billing/api.rb` reopens `module Billing`, so the `Billing` module counts as public.
5. ArchSpec reads only `app/**/*.rb`, `lib/**/*.rb`, `packs/*/app/**/*.rb` and `engines/*/app/**/*.rb` by default. Packwerk reads `**/*.{rb,rake,erb}` except `bin`, `node_modules`, `script`, `tmp` and `vendor`. To catch N1 and N2, the `Archspec.rb` needs `source "app/**/*.rb", "lib/**/*.rb", "test/**/*.rb", "lib/tasks/**/*.rake"`, and the rake file must join the component with an `in:` glob, because a rake file defines no constant for the namespace selector to match.

Neither tool follows dynamic lookups (C07, C08) or calls on objects that an association returns (C18).

### The facts file

The facts file of `archspec reflect` records a hash of each analyzed file, the files under `config/`, the `Gemfile`, `Gemfile.lock` and the Ruby version file. When any of them changes, `archspec check` fails with "stale facts file" until `reflect` runs again. A comment in `app/models/sales/order.rb` was enough to make it stale.

This is more work than Packwerk needs. Packwerk reads `class_name:` from the source and boots the app inside `packwerk check`, so there is no second step and no file to keep current. With ArchSpec, a check after each change needs `reflect` (an app boot) and then `check` (a whole-project analysis). The `reflect` step took about 0.65s on `modules_app`. The ArchSpec times in this report do not include it.

The facts file also depends on the ArchSpec build. A file that `master` wrote is stale for the PR #36 build, because that build also analyzes the ERB files.

### ERB support needs one more fix

PR #36 extracts the Ruby from each template with `Herb.extract_ruby` and parses it with Prism. Layouts and partials call `yield` at the top level, and Prism rejects that code with `Invalid yield`. On the Fizzy checkout from ArchSpec's own torture tests, this gives 23 syntax errors. Prism's `partial_script: true` option accepts top-level `yield`. With the option, the 23 errors go away and no other result changes.

The fix is on the local branch `erb-partial-script` (commit `1511912`, on top of PR #36). It is not offered to the PR author yet.

One alternative does not work. `Herb.extract_ruby(comments: true)` keeps ERB comments as Ruby comments. But a Ruby comment runs to the end of the line, so `<%# note %><%= User.count %>` loses the reference to `User` with no error. The separate comment pass in PR #36 is the correct design.

The speed of the ERB pass was not measured, because the generated benchmark apps have no templates.

## Speed

### Full check on generated apps

The generated apps use the packs layout. Each pack has classes with 20 methods, a reference to the public API of the previous pack, and a private reference in one file out of 25. Each pack depends on the previous pack. The `Archspec.rb` declares the same dependencies as each `package.yml` (with `can_only_use`) and the same privacy (with `public_api`), so all tools check the same rules. All tools found the planted violations.

The table shows the median of three runs, all in one session. The raw times are in `results/bench.raw`, and `scripts/bench.sh` reproduces the table.

| Files | Packs | ArchSpec `master` | ArchSpec + PR #37 | Packwerk | Packwerk with `cache: true` | pks (`--no-cache`) |
|---|---|---|---|---|---|---|
| 1,025 | 7 | 1.33s | 1.33s | 0.73s | 0.66s | 0.09s |
| 2,524 | 10 | 3.55s | 3.52s | 0.84s | 0.77s | 0.11s |
| 5,028 | 10 | 7.33s | 7.46s | 1.07s | 0.92s | 0.22s |
| 5,030 | 17 | 8.56s | 8.84s | 1.07s | 0.93s | 0.23s |
| 5,060 | 42 | 17.8s | 19.1s | 1.11s | 0.98s | 0.22s |

Caveats:

- The apps are synthetic. Real apps have a different shape, for example fewer methods per class and more concerns.
- The benchmark uses file globs for the ArchSpec components, not the `namespace:` selector that the modules layout uses. The cost of namespace selection was not measured.
- Absolute times vary between sessions on this machine by up to 50%. For example, Packwerk took 1.0s and 1.6s on the 5,000-file app in two sessions. Compare the tools only within one table.
- Packwerk runs through `bundle exec`, which boots the app. ArchSpec runs directly with `ruby -I`.

### Check of one file

A pre-commit hook usually checks only the changed files. Median of three runs, same session:

| App | ArchSpec `master` | ArchSpec + PR #37 | Packwerk | Packwerk with `cache: true` | pks (`--no-cache`) |
|---|---|---|---|---|---|
| 5,028 files, 10 packs | 7.80s | 7.69s | 0.59s | 0.59s | 0.10s |
| 5,060 files, 42 packs | 19.3s | 19.3s | 0.60s | 0.59s | 0.10s |

`archspec check <paths>` analyzes the whole project and then keeps only the violations in those paths. So a check of one file costs the same as a full check. With association facts, it also needs `reflect` first.

### Why Packwerk is faster

- **Parallel work.** Packwerk forks one worker per CPU by default, and it can check each file independently. ArchSpec runs in one process.
- **Constant lookup by file name.** Packwerk finds the file of a constant from its name, with the Zeitwerk naming rules. It does not parse a file to learn what the file defines. ArchSpec builds a full index of definitions, ancestors and methods with Rubydex. That index also handles code that does not follow Zeitwerk naming.
- **Privacy rules grow with the square of the pack count.** Each `public_api` rule checks every dependency edge, and each check loops over all components. So the cost grows with edges × packs². This follows from the source (`component_names_for_constant` and `component_names_for_path` in `model.rb`). In an earlier session on the 42-pack app, 10 `public_api` rules added 1.7s and 42 rules added 7.8s.
- **Method analysis.** ArchSpec builds method tables and call sites, which only `cannot_call`, protocol and naming rules use. On a generated 5,000-file app, the profile gives about 1.9s of 4.5s of analysis to that work. An experiment that skipped it (and the call-site edges) cut a check from 7.0s to 4.0s with the same violations. On Discourse, the same work is 8% of the run on `master` and 14% with PR #37. The experiment also changes the "analysis gaps" output, so it is not a pure speed change.
- **pks is a compiled implementation** of the same checks. It is 4 to 5 times faster than Packwerk here.

### Concern analysis on real apps (PR #37)

Profiles on real apps showed a regression on ArchSpec `master`. The concern support from commit `ce3f325` scanned every edge of the graph once for each concern mixin and each concern block. A full check on Discourse took 2.91s on 1.1.0 and 4.24s on `master` in one session.

[crmne/archspec#37](https://github.com/crmne/archspec/pull/37) makes each of those steps visit only the edges it can change. It also adds a regression test for the sequence that a review asked about.

Median analysis time of five runs, on ArchSpec's torture checkouts:

| | Fizzy | Mastodon | Discourse |
|---|---|---|---|
| `master` | 0.41s | 1.90s | 4.43s |
| PR #37 | 0.29s | 1.31s | 2.91s |

A full check on Discourse with PR #37 took 2.96s, about the same as 1.1.0 in the same session. To confirm that the PR does not change behavior, a script (`scripts/graph_digest.rb`) hashes all edges in order, the constants with their mixins and methods, and the violations. The hashes are identical to `master` on all three apps. PR #37 does not help the generated apps, because they have no concerns. None of the torture apps uses Packwerk, so there is no Packwerk time for them.

## Fit with normal Rails

### Configuration

- **Domain declaration.** ArchSpec declares a domain by namespace: `component :billing, namespace: "Billing"`. That covers the Ruby files of the namespace in all Rails folders. Views, tests and rake tasks need extra `in:` and `source` globs (see note 5 above). Packwerk defines a package by directory. On the modules layout, it needs one `package.yml` per namespaced folder. This small app has six such folders. `app/models/billing.rb` falls into the root package.
- **Public API.** ArchSpec accepts a namespace, exact constants or a file glob as the public API. Use `namespace:` for an API module that has nested constants. In packwerk-extensions, `public_path` must be a directory. On the modules layout, each public file can carry a `# pack_public: true` comment in its first five lines instead. Then all other constants stay private by default. The packwerk-extensions README calls this comment a work in progress. A `private_constants` deny list is the other option, but with a deny list each new constant is public until someone adds it.
- **Existing violations.** Both tools record them in a todo file, and entries survive line moves in both. Packwerk records one entry per file and constant. The ArchSpec entry also includes the source constant and the kind of reference ("references", "includes", "inherits from"), so it is finer. After a file has an entry, new references of the same kind to the same constant in that file pass without notice in both tools.
- **Obsolete todo entries.** `packwerk check` fails when the todo file lists a violation that no longer exists ("There were stale violations found"). ArchSpec 1.1.0 and `master` pass in the same situation. The open PR [crmne/archspec#34](https://github.com/crmne/archspec/pull/34) adds `--check-todo` for this.
- **Other rules.** Packwerk validates that the package dependency graph has no cycles (`packwerk validate`). packwerk-extensions adds `visibility` (which packs can use a pack) and `layer` checks. ArchSpec has the equivalents (`no_cycles`, `can_only_be_used_by`, layered presets), and it also checks rules at the class level that Packwerk does not: forbidden method calls (`cannot_call`), method protocols (`must_implement`), naming, and the MVC rules of its Rails presets.

### The modules layout is plain Rails

The modules layout needs no change to Rails. A domain is a folder and a namespace, and Zeitwerk loads it with the default settings. The packs layout moves code out of the paths that Rails and its tools expect.

[packs-rails](https://github.com/rubyatscale/packs-rails) 0.1.0 is the gem that connects packs to Rails. It adds the directories of each pack to the Rails paths, and it has integrations for RSpec and FactoryBot. The third column shows the packs layout with packs-rails and without the manual autoload line. These checks ran on copies of the fixture apps:

| Check | Modules layout | Packs layout | Packs layout with packs-rails |
|---|---|---|---|
| Autoloading | Default Rails settings | `config/application.rb` needs an extra line that adds `packs/*/app/*` to `eager_load_paths` | Works with no extra configuration, including `app/public` |
| `bin/rails g model billing/charge` | Writes `app/models/billing/charge.rb`, its test and its fixture in the correct places. It reports a conflict with the existing `app/models/billing.rb` and offers to replace it with a `table_name_prefix` module. Answer "no", or pass `--skip`, to keep the file | Writes the same files in the root `app/` and `test/`, outside `packs/billing/`. It also writes a second `app/models/billing.rb` | The same as without packs-rails: the files go to the root `app/` and `spec/` |
| `bin/rails test` (Minitest) | Runs `test/models/billing/discovery_test.rb` (1 run) | Does not find `packs/billing/test/models/billing/discovery_test.rb` (0 runs). `DEFAULT_TEST='{test,packs/*/test}/**/*_test.rb' bin/rails test` finds it (1 run) | The same as without packs-rails. packs-rails has no Minitest integration |
| `rspec` | Not tested | Not tested | Plain `rspec` finds no pack specs. `rspec --require packs/rails/rspec` finds `packs/billing/spec/models/billing/discovery_spec.rb` (1 example) |
| ArchSpec `architecture :rails` preset | A model in `app/models/sales/` that uses a controller fails with "models must not depend on controllers" | The same model in `packs/sales/app/models/sales/` is in no component, so the check passes without a warning | The same as without packs-rails (0 violations). ArchSpec reads the files statically, so the Rails paths do not change its components |

So the packs layout can reach most of this with configuration: packs-rails for autoloading, `DEFAULT_TEST` or the RSpec integration for tests, and a move step after each generator run. pks has a `move` command for that step, which was not tested here. The ArchSpec presets for Rails are the exception. They use `app/**` paths, so on a packs layout each preset must be redeclared with pack paths. On the modules layout, the presets work as they are, together with the rules for each domain.

Other tools that read the standard Rails paths were not tested here.

## Open items

- ArchSpec association reflection is on `master` only. It is not in a release yet.
- PR #36 (ERB) is a draft. It needs the `partial_script` fix, and its author is still working on the rule that views cannot use models (it gives 100 violations on Fizzy).
- PR #37 is open. Mutation testing on its changed lines left three surviving mutants. One is in new code (`owned_edges`, line 120) and is equivalent: the callers also filter by location and edge type, and a graph digest on a concern fixture did not change. The other two are in the `calls` filter of callbacks. The same mutants survive on `master`, so they are older gaps in the concern tests.
- No real app that uses Packwerk was measured. The torture apps (Discourse, Mastodon, Fizzy) do not use Packwerk.

## Reproduce

The scripts need Ruby 3.4.6 and Bundler. The benchmark also needs the `pks` binary.

```sh
scripts/setup.sh                  # check out the ArchSpec builds and install the gems
scripts/detect.sh                 # run every tool on the fixture apps
PKS=path/to/pks scripts/bench.sh  # run the benchmark (this takes some minutes)
```

`scripts/setup.sh` clones ArchSpec into `vendor/archspec/` and checks out three builds at fixed commits:

| Folder | Build |
|---|---|
| `master` | `master` at `207381e` |
| `pr36` | PR #36 at `8317031`, with `patches/erb-partial-script.patch` applied |
| `pr37` | PR #37 at `2110c4a` |

The Gemfiles of the fixture apps use the `pr36` build. Set `ARCHSPEC_PATH` to use a different build. The 1.1.0 column uses the released gem.

| Path | What it is |
|---|---|
| `modules_app/` | The modules layout, with `Archspec.rb` and the fixtures. It also holds the `package.yml` files from the test of Packwerk on this layout. |
| `packs_app/` | The Packwerk layout, with `packwerk.yml`, `package.yml` files and an `Archspec.rb` for the same layout. |
| `results/` | The output of `scripts/detect.sh` and `scripts/bench.sh`. For each ArchSpec run, the `.txt` file maps the violations to the `# CASE` comments. |
| `patches/` | The local fix for PR #36. It parses the Ruby code from ERB as a partial script. |
| `scripts/gen_bench.rb` | Generates a benchmark app: `ruby scripts/gen_bench.rb DIR PACKS FILES`. It copies `packs_app/` and writes an `Archspec.rb` with the same rules as the `package.yml` files. `scripts/bench.sh` generates its apps in `bench/`. |
| `scripts/median_bench.rb`, `scripts/graph_digest.rb` | Time the analysis and hash the graph on the torture apps. To get the torture apps, run `bundle exec rake torture` in `vendor/archspec/master`. |
| `scripts/report_archspec.rb` | Maps ArchSpec JSON output to the `# CASE` comments. Its pattern reads `C05b` as `C05`, so check the line numbers for the lettered cases. |

The N1 to N3 cases were run on scratch copies of the apps and are not in the fixture folders. The profiles of the concern analysis and the mutation runs are not in this repository.
