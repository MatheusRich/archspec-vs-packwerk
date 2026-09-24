# usage: ruby scripts/gen_bench.rb DIR PACKS FILES_TOTAL
# Copies packs_app/ to DIR and adds PACKS generated packs with FILES_TOTAL files.
require "fileutils"
dir, packs, total = File.expand_path(ARGV[0]), ARGV[1].to_i, ARGV[2].to_i
per = total / packs
FileUtils.rm_rf(dir); FileUtils.mkdir_p(File.dirname(dir)); FileUtils.cp_r(File.expand_path("../packs_app", __dir__), dir)
Dir.chdir(dir)
# The app is one folder deeper than packs_app/, so its path to ArchSpec needs one more "../".
%w[Gemfile Gemfile.lock].each { File.write(_1, File.read(_1).gsub("../vendor/archspec/", "../../vendor/archspec/")) }
# The N1 to N3 fixtures are newer than the benchmark, so they are removed to keep the measured apps.
FileUtils.rm_rf(%w[archspec_todo.yml packs/sales/test packs/sales/lib packs/billing/app/public/billing/api packs/sales/app/models/sales/api_result.rb]); Dir["**/package_todo.yml"].each { File.delete(_1) }
packs.times do |i|
  mod = "Pack#{i}"; base = "packs/pack#{i}"
  FileUtils.mkdir_p(["#{base}/app/models/pack#{i}", "#{base}/app/public/pack#{i}"])
  File.write("#{base}/package.yml", "enforce_dependencies: true\nenforce_privacy: true\ndependencies:\n  - \".\"\n#{i > 0 ? "  - packs/pack#{i - 1}\n" : ""}")
  File.write("#{base}/app/public/pack#{i}/api.rb", "module #{mod}\n  module Api\n    def self.call = Thing0\n  end\nend\n")
  per.times do |j|
    body = (1..20).map { |k| "    def m#{k}(x) = x.to_s * #{k}\n" }.join
    refs = ["Thing#{(j + 1) % per}.new"]
    refs << "Pack#{i - 1}::Api.call" if i > 0
    refs << "Pack#{i - 1}::Thing#{j}.new" if i > 0 && j % 25 == 0
    File.write("#{base}/app/models/pack#{i}/thing#{j}.rb", "module #{mod}\n  class Thing#{j}\n#{body}    def run\n      #{refs.join("\n      ")}\n    end\n  end\nend\n")
  end
end
File.write("Archspec.rb", <<~'R')
  # One component per pack, with the same dependencies as its package.yml,
  # so ArchSpec checks the same rules as Packwerk: dependencies and privacy.
  require "yaml"
  packs = each_directory("packs/*")
  packs.each do |name, path|
    component(name.to_sym, in: "#{path}/**/*.rb").public_api("#{path}/app/public/**/*.rb")
  end
  packs.each do |name, path|
    deps = Array(YAML.load_file(File.join(__dir__, path, "package.yml"))["dependencies"])
    public_send(name).can_only_use(*deps.grep(%r{\Apacks/}).map { |dep| File.basename(dep).to_sym })
  end
R
