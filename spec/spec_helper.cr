require "file_utils"

require "spectator"

require "../src/envtpl"

# see: https://github.com/crystal-lang/crystal/blob/master/spec/support/env.cr
def with_env(values : Hash, &)
  old_values = {} of String => String?
  begin
    values.each do |key, value|
      key = key.to_s
      old_values[key] = ENV[key]?
      ENV[key] = value
    end

    yield
  ensure
    old_values.each do |key, old_value|
      ENV[key] = old_value
    end
  end
end

def with_env(**values, &)
  with_env(values.to_h) { yield }
end

# Path of the CLI binary used by the integration specs.
#
# Exit codes, the exact bytes written to STDOUT and the STDIN/`--in` split can
# only be observed from a real process, so `src/cli.cr` is compiled here.
#
# It is compiled into `bin/` (gitignored, wiped by `mise dev:clean`) and
# unconditionally rebuilt on every run, so it can never go stale. Do NOT move
# this to a temporary path cleaned up by `at_exit`: Spectator runs the whole
# suite from its own `at_exit` handler, and handlers run last-registered-first,
# so the cleanup would delete the binary *before* a single example runs.
CLI_BINARY = begin
  binary = File.expand_path("../bin/envtpl-spec", __DIR__)
  source = File.expand_path("../src/cli.cr", __DIR__)

  Dir.mkdir_p(File.dirname(binary))
  status = Process.run("crystal", ["build", "-o", binary, source], output: :inherit, error: :inherit)
  raise "Failed to compile #{source} for the integration specs" unless status.success?

  binary
end

# Result of a CLI invocation: exit code plus the raw bytes of both streams.
record CLIResult, exit_code : Int32, stdout : String, stderr : String do
  def success?
    exit_code.zero?
  end
end

# Runs the compiled CLI with *args*, feeding *input* on STDIN and *env* in the
# environment. Never raises on a non-zero exit: the exit code is part of what
# the specs assert.
def run_cli(args : Array(String) = [] of String, input : String = "", env : Hash(String, String?) = {} of String => String?) : CLIResult
  stdout = IO::Memory.new
  stderr = IO::Memory.new

  status = Process.run(
    CLI_BINARY,
    args,
    input: IO::Memory.new(input),
    output: stdout,
    error: stderr,
    env: env
  )

  CLIResult.new(status.exit_code, stdout.to_s, stderr.to_s)
end

# Yields a path in a fresh temporary directory, removed afterwards. Used by the
# specs that exercise `--in`/`--out`.
def with_tmp_dir(&)
  dir = File.tempname("envtpl-spec-dir", "")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end
