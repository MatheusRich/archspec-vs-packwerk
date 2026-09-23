# usage: ruby scripts/graph_digest.rb ARCHSPEC_LIB APP_DIR
# Prints a digest of the analyzed graph and the check wall time, so two
# archspec builds can be compared for identical output.
$LOAD_PATH.unshift File.expand_path(ARGV[0])
require "archspec"
require "digest"
require "json"
require "stringio"
Dir.chdir(ARGV[1]) do
  definition, root = ArchSpec::CLI.send(:load_definition, "Archspec.rb")
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  graph = ArchSpec::Analyzer.analyze(definition, root: root)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  edges = graph.edges.map { |e| e.to_h.transform_values(&:to_s).sort.to_s }.sort
  order_sha = Digest::SHA256.hexdigest(graph.edges.map { |e| e.to_h.transform_values(&:to_s).sort.to_s }.join("\n"))[0, 12]
  constants = graph.constants.map do |c|
    [c.name, c.path, c.mixins.transform_values { _1.to_a }.sort.to_s,
     c.method_definitions.map(&:to_s).sort.to_s].to_s
  end.sort
  out = StringIO.new
  ArchSpec::CLI.run(%w[check --format json], output: out, error: $stderr)
  violations = JSON.parse(out.string)["violations"].map(&:to_s).sort
  puts format("%-10s analyze=%.2fs edges=%d order_sha=%s edges_sha=%s constants_sha=%s violations=%d violations_sha=%s",
              File.basename(ARGV[1]), elapsed, edges.size, order_sha, Digest::SHA256.hexdigest(edges.join("\n"))[0, 12],
              Digest::SHA256.hexdigest(constants.join("\n"))[0, 12], violations.size,
              Digest::SHA256.hexdigest(violations.join("\n"))[0, 12])
end
