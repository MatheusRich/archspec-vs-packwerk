# ArchSpec with namespaced modules as a replacement for Packwerk

This repository compares two ways to enforce boundaries between the domains of a Rails app:

- **Namespaced modules with [ArchSpec](https://archspecrb.dev/).** Each domain is a Ruby namespace (`Billing`, `Sales`) in the standard Rails folders (`app/models/billing/`, `app/controllers/sales/`). ArchSpec checks the boundaries with static analysis.
- **[Packwerk](https://github.com/Shopify/packwerk) with packwerk-extensions.** Each domain is a package directory (`packs/billing/`) with a `package.yml`. The comparison also measures [pks](https://github.com/alexevanczuk/packs), a Rust implementation of the Packwerk checks that reads the same configuration.

The question: can the first approach replace Packwerk? This report compares what each tool catches, how fast it is, and how well it fits a normal Rails app.

All results are from 2026-09-23, on one machine.

## Summary

The two approaches catch the same violations. ArchSpec is better for the app, because the code stays in a plain Rails layout. Packwerk is better for the check itself: it is faster, it needs one command, and it is mature.

### Detection is equal

With the correct configuration, each tool catches 18 of the 20 violations in the test set. Neither tool follows dynamic lookups such as `constantize`. Two ArchSpec features are not released yet. Association support is on `master` only. ERB support is in a draft PR that needs one more fix.

### ArchSpec is better for the app

- **Plain Rails.** A domain is a folder and a namespace in the standard Rails folders. Zeitwerk loads it with the default settings. Generators write to the correct folders, and `bin/rails test` finds the tests. A generator asks for confirmation only before it replaces an existing namespace file.
- **Configuration.** One `Archspec.rb` file holds all rules. One line declares a domain by namespace, in all Rails folders. The public API can be a namespace. Packwerk needs a `package.yml` in each package directory.
- **More rules.** The ArchSpec presets for Rails (for example, "models must not depend on controllers") work together with the rules for each domain. ArchSpec also checks class-level rules that Packwerk does not have: forbidden method calls, method protocols and naming.
- **Exact locations.** ArchSpec reports the line and column, also in ERB. Packwerk reported one ERB violation at `1:1`.

On the packs layout, most Rails tools need extra configuration: packs-rails, a test glob, and a move step after each generator. Also, the ArchSpec presets for Rails do not see the code in packs.

### Packwerk is better for the check

- **Speed.** Packwerk is faster at every measured size. A full check on 5,000 files takes about 1s with Packwerk, 0.2s with pks, and 7s to 18s with ArchSpec. A check of one file takes 0.6s with Packwerk, 0.1s with pks, and 8s to 19s with ArchSpec, because ArchSpec always analyzes the whole project. On 1,000 files, ArchSpec takes 1.3s. So the difference matters most for large apps and for pre-commit hooks.
- **One step.** For association checks, ArchSpec needs `archspec reflect` (an app boot) before `archspec check`. Any change to the source or the configuration makes the facts file stale. Packwerk reads associations from the source in one command.
- **Defaults.** Packwerk reads tests, rake tasks and ERB files by default. ArchSpec needs extra `source` and `in:` globs for them.
- **Obsolete todo entries.** Packwerk fails when the todo file lists a violation that no longer exists. ArchSpec needs an open PR for this.
- **Maturity.** Packwerk and its tools are several years old. ArchSpec is at version 1.1.0, and its first pull request is from 2026-06-24. One author wrote 89 of its 91 commits.

### Recommendation

For a small or mid-size app, use namespaced modules with ArchSpec. The layout stays plain Rails, and a full check takes a few seconds: 1.3s on 1,000 files and 3.5s on 2,500 files. Wait for a release that includes association reflection and ERB support. For a large app that needs fast checks on each commit, or for an app that already uses packs, use Packwerk or pks.

## Setup

| Item | Version |
|---|---|
| Ruby | 3.4.6 (macOS, 14 CPUs: 10 performance and 4 efficiency cores) |
| Rails | 8.1.3.1 |
| ArchSpec | 1.1.0 (released), `master` at `207381e`, and `master` with PR #36 plus a fix (`patches/erb-partial-script.patch`) |
| Packwerk | 3.3.1, with packwerk-extensions 0.3.0 for privacy checks |
| pks | 0.2.40 |
| Herb | 0.10.4 (PR #36 uses it to read ERB) |

There are two versions of one small Rails app:

- `modules_app/` uses the modules layout. Its `Archspec.rb` declares `billing` and `sales` by namespace and adds the ERB views with `in:`. `sales` can only use `billing`. `billing` cannot use `sales`. Only the `Billing::Api` namespace is public.
- `packs_app/` uses the Packwerk layout, with the same code in `packs/billing/` and `packs/sales/`. `packs/sales` depends on `packs/billing`. `packs/billing` enforces privacy, and its public folder holds `Billing::Api`.

Each fixture file marks its case with a `# CASE Cxx` comment. The test set is hand-written, so it does not prove that either tool is complete.

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

The test set also has controls, which a tool must not flag. No tool flagged a control. Some controls apply only to some columns:

| Control | What the code does | Result |
|---|---|---|
| C00, C14 | Sales calls the public `Billing::Api` from a model and a job | No tool flags it |
| C05d | `class_name: "Sales::Order"` inside Sales | No tool flags it |
| C11c | A Sales ERB view calls `Billing::Api` | No tool flags it. This applies only to the columns that read ERB |
| N3 | Sales uses `Billing::Api::Result`, a constant nested in the public API | Packwerk does not flag it. ArchSpec with `public_api namespace: "Billing::Api"` does not flag it. ArchSpec with `public_api constants: "Billing::Api"` flags it, because `constants:` matches exact names only |

Notes:

1. `archspec reflect` boots the app and gets the association targets from Active Record. It writes a facts file that `archspec check` reads. See [The facts file](#the-facts-file).
2. Both tools see only the reference to the `Billing` module, not the lookup of `Invoice`. The totals count the case as caught, but neither tool detects the reference to the private constant.
3. Packwerk reports the ERB violation at `1:1`, but the reference is on line 2. ArchSpec reports the correct line and column.
4. ArchSpec flags C08 and C22 because the `Billing` module itself is private in this configuration. On the packs layout with a file glob for `public_api`, ArchSpec does not flag them. There, `app/public/billing/api.rb` reopens `module Billing`, so the `Billing` module is public.
5. By default, ArchSpec reads only `app/**/*.rb`, `lib/**/*.rb`, `packs/*/app/**/*.rb` and `engines/*/app/**/*.rb`. Packwerk reads `**/*.{rb,rake,erb}`, except `bin`, `node_modules`, `script`, `tmp` and `vendor`. To catch N1 and N2, `Archspec.rb` needs `source "app/**/*.rb", "lib/**/*.rb", "test/**/*.rb", "lib/tasks/**/*.rake"`. The rake file also needs an `in:` glob on the component, because a rake file defines no constant that the namespace selector can match.

Neither tool follows dynamic lookups (C07, C08) or calls on objects that an association returns (C18).

### The facts file

`archspec reflect` writes a facts file with a hash of each analyzed file, the files in `config/`, the `Gemfile`, `Gemfile.lock` and the Ruby version file. When one of these files changes, `archspec check` fails with "stale facts file" until `reflect` runs again. A new comment in `app/models/sales/order.rb` makes the facts file stale.

Packwerk does not need this step. It reads `class_name:` from the source and boots the app inside `packwerk check`. With ArchSpec, a check after each change needs `reflect` (an app boot) and then `check` (a whole-project analysis). `reflect` takes about 0.65s on `modules_app`. The ArchSpec times in this report do not include it.

The facts file also depends on the ArchSpec build. A facts file from `master` is stale for the PR #36 build, because that build also analyzes the ERB files.

### ERB support needs one more fix

PR #36 extracts the Ruby code from each template with `Herb.extract_ruby` and parses it with Prism. Layouts and partials call `yield` at the top level, and Prism rejects this with `Invalid yield`. On Fizzy, one of the apps in ArchSpec's torture tests, this causes 23 syntax errors. Prism's `partial_script: true` option accepts a top-level `yield`. With this option, the 23 errors stop and no other result changes. `patches/erb-partial-script.patch` applies the option on top of PR #36.

`Herb.extract_ruby(comments: true)` is not an alternative. It keeps ERB comments as Ruby comments, and a Ruby comment continues to the end of the line. So `<%# note %><%= User.count %>` loses the reference to `User`, with no error. The separate comment pass in PR #36 is correct.

The generated benchmark apps have no templates, so there is no measurement of the ERB pass speed.

## Speed

### Full check on generated apps

The generated apps use the packs layout. In each pack, the classes have 20 methods. Each pack depends on the previous pack and calls its public API. One file in 25 also has a private reference to the previous pack. The `Archspec.rb` declares the same dependencies as each `package.yml` (with `can_only_use`) and the same privacy (with `public_api`), so all tools check the same rules. All tools found all the violations.

The table shows the median of three runs. The raw times are in `results/bench.raw`.

| Files | Packs | ArchSpec `master` | ArchSpec + PR #37 | Packwerk | Packwerk with `cache: true` | pks (`--no-cache`) |
|---|---|---|---|---|---|---|
| 1,025 | 7 | 1.33s | 1.33s | 0.73s | 0.66s | 0.09s |
| 2,524 | 10 | 3.55s | 3.52s | 0.84s | 0.77s | 0.11s |
| 5,028 | 10 | 7.33s | 7.46s | 1.07s | 0.92s | 0.22s |
| 5,030 | 17 | 8.56s | 8.84s | 1.07s | 0.93s | 0.23s |
| 5,060 | 42 | 17.8s | 19.1s | 1.11s | 0.98s | 0.22s |

Limits of this benchmark:

- The apps are synthetic. Real apps have a different shape, for example fewer methods per class and more concerns.
- The ArchSpec components use file globs, not the `namespace:` selector of the modules layout. There is no measurement of the cost of namespace selection.
- Absolute times vary by up to 50% from run to run. For example, Packwerk took 1.0s in one run and 1.6s in a different run on the 5,000-file app. Compare the tools only inside one table.
- Packwerk runs through `bundle exec`, which boots the app. ArchSpec runs directly with `ruby -I`.

### Check of one file

A pre-commit hook usually checks only the changed files. Median of three runs:

| App | ArchSpec `master` | ArchSpec + PR #37 | Packwerk | Packwerk with `cache: true` | pks (`--no-cache`) |
|---|---|---|---|---|---|
| 5,028 files, 10 packs | 7.80s | 7.69s | 0.59s | 0.59s | 0.10s |
| 5,060 files, 42 packs | 19.3s | 19.3s | 0.60s | 0.59s | 0.10s |

`archspec check <paths>` analyzes the whole project, and then shows only the violations in those paths. So a check of one file takes as long as a full check. With association facts, it also needs `reflect` first.

### Why Packwerk is faster

- **Parallel work.** By default, Packwerk starts one worker per CPU and checks each file independently. ArchSpec runs in one process.
- **Constant lookup by file name.** Packwerk finds the file of a constant from its name, with the Zeitwerk naming rules. It does not parse a file to find what the file defines. ArchSpec uses Rubydex to build a full index of definitions, ancestors and methods. This index also works for code that does not follow the Zeitwerk naming rules.
- **Privacy rules grow with the square of the pack count.** Each `public_api` rule checks every dependency edge, and each check loops over all components. So the cost grows with edges × packs². The source shows this (`component_names_for_constant` and `component_names_for_path` in `model.rb`). On the 42-pack app, 10 `public_api` rules added 1.7s and 42 rules added 7.8s.
- **Method analysis.** ArchSpec builds method tables and call sites. Only the `cannot_call`, protocol and naming rules use them. On a generated 5,000-file app, this work takes about 1.9s of the 4.5s analysis. A build that skips this work (and the call-site edges) cut a check from 7.0s to 4.0s, with the same violations. On Discourse, this work is 8% of the run on `master` and 14% with PR #37. The build that skips it also changes the "analysis gaps" output, so it is not only a speed change.
- **pks is compiled.** It runs the same checks 4 to 5 times faster than Packwerk.

### Concern analysis on real apps (PR #37)

ArchSpec `master` is slower than 1.1.0 on real apps. The concern support from commit `ce3f325` scans every edge of the graph once for each concern mixin and each concern block. A full check on Discourse took 2.91s on 1.1.0 and 4.24s on `master`.

[crmne/archspec#37](https://github.com/crmne/archspec/pull/37) makes each of these steps visit only the edges that it can change.

Median analysis time of five runs, on the apps from ArchSpec's torture tests:

| | Fizzy | Mastodon | Discourse |
|---|---|---|---|
| `master` | 0.41s | 1.90s | 4.43s |
| PR #37 | 0.29s | 1.31s | 2.91s |

A full check on Discourse with PR #37 took 2.96s, about the same as 1.1.0. PR #37 does not change behavior: `scripts/graph_digest.rb` hashes all edges in order, the constants with their mixins and methods, and the violations, and the hashes are identical to `master` on all three apps. PR #37 does not make the generated apps faster, because they have no concerns. The torture apps do not use Packwerk, so there are no Packwerk times for them.

## Fit with normal Rails

### Configuration

- **Domain declaration.** ArchSpec declares a domain by namespace: `component :billing, namespace: "Billing"`. This includes the Ruby files of the namespace in all Rails folders. Views, tests and rake tasks need extra `in:` and `source` globs (see note 5). Packwerk defines a package by directory. On the modules layout, it needs one `package.yml` for each namespaced folder. This small app has six of these folders. `app/models/billing.rb` is in the root package.
- **Public API.** In ArchSpec, the public API can be a namespace, a list of exact constants or a file glob. Use `namespace:` for an API module that has nested constants. In packwerk-extensions, `public_path` must be a directory. On the modules layout, each public file can have a `# pack_public: true` comment in its first five lines instead. All other constants are then private by default. The packwerk-extensions README calls this comment a work in progress. The other option is a `private_constants` list. With that list, each new constant is public until someone adds it to the list.
- **Existing violations.** Both tools record existing violations in a todo file. In both tools, an entry stays valid when the reference moves to a different line. Packwerk records one entry for each file and constant. An ArchSpec entry also records the source constant and the kind of reference ("references", "includes", "inherits from"), so it is more specific. In both tools, when a file has an entry, new references of the same kind to the same constant in that file pass with no message.
- **Obsolete todo entries.** `packwerk check` fails when the todo file lists a violation that no longer exists ("There were stale violations found"). ArchSpec 1.1.0 and `master` pass. The open PR [crmne/archspec#34](https://github.com/crmne/archspec/pull/34) adds `--check-todo` for this.
- **Other rules.** `packwerk validate` checks that the package dependency graph has no cycles. packwerk-extensions adds `visibility` checks (which packs can use a pack) and `layer` checks. ArchSpec has equivalents: `no_cycles`, `can_only_be_used_by` and the layered presets. It also checks class-level rules that Packwerk does not have: forbidden method calls (`cannot_call`), method protocols (`must_implement`), naming, and the MVC rules of its Rails presets.

### The modules layout is plain Rails

The modules layout needs no change to Rails. A domain is a folder and a namespace, and Zeitwerk loads it with the default settings. The packs layout moves code out of the paths that Rails and its tools use.

[packs-rails](https://github.com/rubyatscale/packs-rails) 0.1.0 connects packs to Rails. It adds the directories of each pack to the Rails paths, and it has integrations for RSpec and FactoryBot. The third column shows the packs layout with packs-rails and without the manual autoload line.

| Check | Modules layout | Packs layout | Packs layout with packs-rails |
|---|---|---|---|
| Autoloading | Default Rails settings | `config/application.rb` needs an extra line that adds `packs/*/app/*` to `eager_load_paths` | No extra configuration, including `app/public` |
| `bin/rails g model billing/charge` | Writes `app/models/billing/charge.rb`, its test and its fixture in the correct folders. It reports a conflict with the existing `app/models/billing.rb` and offers to replace it with a `table_name_prefix` module. Answer "no", or pass `--skip`, to keep the file | Writes the same files in the root `app/` and `test/`, not in `packs/billing/`. It also writes a second `app/models/billing.rb` | The same as without packs-rails: the files go to the root `app/` and `spec/` |
| `bin/rails test` (Minitest) | Runs `test/models/billing/discovery_test.rb` (1 run) | Does not find `packs/billing/test/models/billing/discovery_test.rb` (0 runs). `DEFAULT_TEST='{test,packs/*/test}/**/*_test.rb' bin/rails test` finds it (1 run) | The same as without packs-rails. packs-rails has no Minitest integration |
| `rspec` | Not tested | Not tested | Plain `rspec` finds no pack specs. `rspec --require packs/rails/rspec` finds `packs/billing/spec/models/billing/discovery_spec.rb` (1 example) |
| ArchSpec `architecture :rails` preset | A model in `app/models/sales/` that uses a controller fails with "models must not depend on controllers" | The same model in `packs/sales/app/models/sales/` is in no component, so the check passes with no warning | The same as without packs-rails (0 violations). ArchSpec reads the files statically, so the Rails paths do not change its components |

So the packs layout can get most of this with configuration: packs-rails for autoloading, `DEFAULT_TEST` or the RSpec integration for tests, and a move step after each generator. pks has a `move` command for that step, which was not tested. The ArchSpec presets for Rails are the exception. They use `app/**` paths, so on the packs layout you must declare each preset again with pack paths. On the modules layout, the presets work with no change, together with the rules for each domain.

Other tools that use the standard Rails paths were not tested.

## Open items

- ArchSpec association reflection is on `master` only. No release includes it yet.
- PR #36 (ERB) is a draft. It needs the `partial_script` fix. Its rule that views cannot use models is not finished (it gives 100 violations on Fizzy).
- PR #37 is open.
- There is no measurement of a real app that uses Packwerk. The torture apps (Discourse, Mastodon, Fizzy) do not use Packwerk.

## Reproduce

The scripts need Ruby 3.4.6 and Bundler. The benchmark also needs the `pks` binary.

```sh
scripts/setup.sh                  # check out the ArchSpec builds and install the gems
scripts/detect.sh                 # run every tool on the fixture apps
PKS=path/to/pks scripts/bench.sh  # run the benchmark (this takes about 8 minutes)
```

`scripts/setup.sh` clones ArchSpec into `vendor/archspec/` and checks out three builds at fixed commits:

| Folder | Build |
|---|---|
| `master` | `master` at `207381e` |
| `pr36` | PR #36 at `8317031`, with `patches/erb-partial-script.patch` applied |
| `pr37` | PR #37 at `2110c4a` |

The Gemfiles of the fixture apps use the `pr36` build. To use a different build, set `ARCHSPEC_PATH`. The 1.1.0 column uses the released gem.

| Path | Contents |
|---|---|
| `modules_app/` | The modules layout, with `Archspec.rb` and the fixtures. It also has `package.yml` files, to run Packwerk on this layout. |
| `packs_app/` | The Packwerk layout, with `packwerk.yml`, the `package.yml` files and an `Archspec.rb` for the same layout. |
| `results/` | The output of `scripts/detect.sh` and `scripts/bench.sh`. For each ArchSpec run, the `.txt` file maps the violations to the `# CASE` comments. |
| `patches/` | The fix for PR #36. It parses the Ruby code from ERB as a partial script. |
| `scripts/gen_bench.rb` | Generates a benchmark app: `ruby scripts/gen_bench.rb DIR PACKS FILES`. It copies `packs_app/` and writes an `Archspec.rb` with the same rules as the `package.yml` files. `scripts/bench.sh` generates its apps in `bench/`. |
| `scripts/median_bench.rb`, `scripts/graph_digest.rb` | Time the analysis and hash the graph on the torture apps. To get the torture apps, run `bundle exec rake torture` in `vendor/archspec/master`. |
| `scripts/report_archspec.rb` | Maps ArchSpec JSON output to the `# CASE` comments. It reads `C05b` as `C05`, so use the line numbers for the cases with a letter. |

The fixture folders do not include the N1 to N3 cases.
