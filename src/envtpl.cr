# Load std libs
require "option_parser"

# Load external libs
require "crinja"

# Declare Crinja function: env()
Crinja.function(:env) do
  if arguments.varargs.empty? && arguments.kwargs.empty?
    Crinja::Value.new(ENV.to_h)
  else
    keys = arguments.varargs.map(&.to_s)
    default = arguments.kwargs.fetch("default", nil)

    if keys.size == 1
      key = keys.first
      value = ENV[key]?

      if value.nil?
        # `default.nil?` alone only tests the `Crinja::Value` wrapper, which is
        # never nil: `default=none` would then render the literal "none".
        if default.nil? || default.raw.nil?
          Crinja::Value.new("")
        else
          Crinja::Value.new(default)
        end
      else
        Crinja::Value.new(value)
      end
    else
      # Read only the requested keys. `ENV.to_h` would copy the whole
      # environment on every single `env()` call in the template.
      selected = {} of String => String
      keys.each do |name|
        if value = ENV[name]?
          selected[name] = value
        end
      end
      Crinja::Value.new(selected)
    end
  end
end

# Declare Crinja filter: json
Crinja.filter({indent: nil}, :json) do
  raw = target.raw
  # A non-numeric indent is a template authoring mistake, not a reason to abort
  # the whole render with a bare `Invalid Int32`: fall back to the default.
  indent = arguments.fetch("indent", 2).to_s.to_i? || 2
  String.build do |io|
    Crinja::JsonBuilder.to_json(io, raw, indent)
  end
end

module Envtpl
  VERSION = {{ `shards version #{__DIR__}`.chomp.stringify }}
  GIT_REF = {{ `git log -n 1 --format="%H" | head -c 8`.chomp.stringify }}

  # Crinja strips the template's trailing newline unless told otherwise, which
  # silently drops the final newline of every rendered file.
  CONFIG = Crinja::Config.new(keep_trailing_newline: true)

  # Template name used in error messages when the source is a pipe.
  STDIN_NAME = "<stdin>"

  # Root context that resolves a missing name to `Crinja::StrictUndefined`.
  #
  # By default a missing name resolves to the shared `Crinja::Undefined`, which
  # stringifies to an empty string: a typo then produces an empty config value
  # and exits 0. `StrictUndefined` raises instead — but only when *printed*, so
  # `default()` and `is defined` keep working, both inspecting the undefined
  # value without ever rendering it. That is also Jinja2's semantics.
  #
  # The shared `Crinja::Undefined` carries no name, hence the re-wrapping here:
  # it is the only place where the name being looked up is still known, and it
  # is what makes the error message say which variable is missing.
  class StrictContext < Crinja::Context
    def [](key : String)
      value = super

      value.undefined? ? Crinja::Value.new(Crinja::StrictUndefined.new(key)) : value
    end
  end

  def self.version
    "#{VERSION} (#{GIT_REF})"
  end

  def self.parse_args!
    source_file = STDIN
    destination_file = STDOUT
    strict = false

    opt_parser = OptionParser.parse do |parser|
      parser.banner = "Usage: envtpl [arguments]"
      parser.on("-i FILE", "--in=FILE", "Specifies the input file (STDIN by default)") { |name| source_file = name }
      parser.on("-o FILE", "--out=FILE", "Specifies the output file (STDOUT by default)") { |name| destination_file = name }
      parser.on("-s", "--strict", "Fail instead of rendering an empty string for an undefined variable") { strict = true }
      parser.on("-v", "--version", "Show version") do
        STDOUT.puts version
        exit 0
      end
      # `Licenses` is required by src/cli.cr, not by this file: see there.
      parser.on("--licenses", "Print the third-party notices embedded in this binary") do
        STDOUT.print Licenses.text
        exit 0
      end
      parser.on("-h", "--help", "Show this help") do
        STDOUT.puts parser
        exit 0
      end
      parser.invalid_option do |flag|
        STDERR.puts "ERROR: #{flag} is not a valid option."
        STDERR.puts parser
        exit 1
      end
    end

    if source_file == STDIN
      # a pipe should be present, but it's not, for exemple
      # when envtpl is called without arguments.
      # render usage and exit 0
      if STDIN.tty?
        STDERR.puts opt_parser
        exit 0
      end
    else
      if !File.exists?(source_file.to_s)
        STDERR.puts "Input file is not readable: #{source_file}"
        exit 1
      end
    end

    {source_file, destination_file, strict}
  end

  def self.convert(source, destination, strict = false)
    content = transform(read(source), name: template_name(source), strict: strict)
    render(content, destination)
  end

  def self.read(source)
    source == STDIN ? STDIN.gets_to_end : File.read(source.to_s)
  end

  # Name reported by template error messages. Without it Crinja falls back to
  # `<string>`, which says nothing about which file failed to render.
  def self.template_name(source)
    source == STDIN ? STDIN_NAME : source.to_s
  end

  def self.transform(content, name = "", strict = false)
    environment = strict ? Crinja.new(StrictContext.new, CONFIG) : Crinja.new(config: CONFIG)
    # Crinja reports `filename` (not `name`) in error locations, falling back to
    # `<string>` when it is nil — hence both are set.
    Crinja::Template.new(content, environment, name: name, filename: name.presence).render(ENV)
  end

  def self.render(content, destination)
    # `print`, not `puts`: `puts` appends a newline the rendered template does
    # not contain, which makes STDOUT differ byte for byte from `--out`.
    destination == STDOUT ? STDOUT.print(content) : File.write(destination.to_s, content)
  end
end
