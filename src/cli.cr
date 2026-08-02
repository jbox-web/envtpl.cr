# Command line entrypoint.
#
# This file is deliberately the *only* place that parses ARGV, touches STDIN or
# calls `exit`. `src/envtpl.cr` is a pure library and can therefore be required
# from a spec without starting the CLI — no runtime environment guard needed.
require "./envtpl"

begin
  source, destination, strict = Envtpl.parse_args!
  Envtpl.convert(source, destination, strict: strict)
rescue e : Exception
  # Print the class as well: `e.message` alone is a blank line whenever the
  # message is nil, which leaves the user with nothing to act on.
  STDERR.puts "#{e.class}: #{e.message}"
  exit 1
end
