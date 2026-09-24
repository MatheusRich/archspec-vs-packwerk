# usage: ruby scripts/report_archspec.rb APP_DIR CHECK_JSON
# Maps each violation to the `# CASE` comment on its line.
require "json"
app = ARGV.fetch(0)
d = JSON.parse(File.read(ARGV.fetch(1)))
d["violations"].sort_by { [_1["path"], _1["line"]] }.each do |v|
  line = File.readlines(File.join(app, v["path"]))[v["line"] - 1].to_s
  kase = line[/CASE ([CN]\d+[a-z]?)/, 1] || "-"
  puts [kase, v["rule"], "#{v["path"]}:#{v["line"]}", v["evidence"]].join(" | ")
end
puts "analysis: #{d["analysis"]}"
