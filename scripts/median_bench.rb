# usage: ruby scripts/median_bench.rb LABEL=LIB... ; median analyze time of 5 runs per app
# The apps come from `bundle exec rake torture` in vendor/archspec/master.
# Set TORTURE to use another folder.
torture = ENV.fetch("TORTURE", File.expand_path("../vendor/archspec/master/tmp/torture", __dir__))
digest = File.expand_path("graph_digest.rb", __dir__)
libs = ARGV.map { _1.split("=", 2) }
apps = %w[fizzy mastodon discourse]
puts format("%-12s %s", "", apps.map { format("%10s", _1) }.join)
libs.each do |label, lib|
  row = apps.map do |app|
    times = 5.times.map do
      `ruby #{digest} #{File.expand_path(lib)} #{torture}/#{app}`[/analyze=([\d.]+)s/, 1].to_f
    end
    format("%9.2fs", times.sort[2])
  end
  puts format("%-12s %s", label, row.join)
end
