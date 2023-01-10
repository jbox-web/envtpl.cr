# Load std libs
require "option_parser"

# Load external libs
require "crystal-env/core"
require "crinja"

# Set environment
Crystal::Env.default("development")

# Declare Crijna function: env()
Crinja.function(:env) do
  if arguments.varargs.empty? && arguments.kwargs.empty?
    Crinja::Value.new(ENV.to_h)
  else
    keys = arguments.varargs.map(&.to_s)
    default = arguments.kwargs.fetch("default", nil)

    if keys.size == 1
      key = keys.first
      value = ENV.to_h[key]?

      if value.nil?
        if default.nil?
          Crinja::Value.new("")
        else
          Crinja::Value.new(default)
        end
      else
        Crinja::Value.new(value)
      end
    else
      Crinja::Value.new(ENV.to_h.select(keys))
    end
  end
end

# Declare Crijna filter: json
Crinja.filter({indent: nil}, :json) do
  raw = target.raw
  indent = arguments.fetch("indent", 2).to_i
  String.build do |io|
    Crinja::JsonBuilder.to_json(io, raw, indent)
  end
end

module Envtpl
  VERSION = "1.1.0"

  def self.parse_args!
    source_file = STDIN
    destination_file = STDOUT

    opt_parser = OptionParser.parse do |parser|
      parser.banner = "Usage: envtpl [arguments]"
      parser.on("-i FILE", "--in=FILE", "Specifies the input file (STDIN by default)") { |name| source_file = name }
      parser.on("-o FILE", "--out=FILE", "Specifies the output file (STDOUT by default)") { |name| destination_file = name }
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

    {source_file, destination_file}
  end

  def self.convert(source, destination)
    content = transform(read(source))
    render(content, destination)
  end

  def self.read(source)
    source == STDIN ? STDIN.gets : File.read(source.to_s)
  end

  def self.transform(content)
    Crinja.render(content, ENV)
  end

  def self.render(content, destination)
    destination == STDOUT ? STDOUT.puts(content) : File.write(destination.to_s, content)
  end
end

# Start the CLI
unless Crystal.env.test?
  begin
    source, destination = Envtpl.parse_args!
    Envtpl.convert(source, destination)
  rescue e : Exception
    STDERR.puts e.message
    exit 1
  end
end
