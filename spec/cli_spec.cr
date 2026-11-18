require "./spec_helper"

# Integration specs: they run the compiled binary, so they cover what the unit
# specs structurally cannot — exit codes, the exact bytes on STDOUT, and the
# equivalence between STDOUT and `--out`.
Spectator.describe "envtpl CLI" do
  describe "rendering" do
    it "renders a template read from STDIN to STDOUT" do
      result = run_cli(input: "Hello {{ FOO }}\n", env: {"FOO" => "bar"})

      expect(result.stdout).to eq "Hello bar\n"
      expect(result.exit_code).to eq 0
    end

    it "does not append a newline the template does not have" do
      result = run_cli(input: "Hello {{ FOO }}", env: {"FOO" => "bar"})

      expect(result.stdout).to eq "Hello bar"
    end

    it "preserves the trailing newline when writing to a file" do
      with_tmp_dir do |dir|
        input = File.join(dir, "in.j2")
        output = File.join(dir, "out.txt")
        File.write(input, "Hello {{ FOO }}\n")

        result = run_cli(["-i", input, "-o", output], env: {"FOO" => "bar"})

        expect(result.exit_code).to eq 0
        expect(File.read(output)).to eq "Hello bar\n"
      end
    end

    # The whole point of the two specs above: whichever destination is used,
    # the bytes must be identical.
    it "writes the same bytes to STDOUT and to --out" do
      with_tmp_dir do |dir|
        input = File.join(dir, "in.j2")
        output = File.join(dir, "out.txt")
        template = "first: {{ FOO }}\nsecond: {{ FOO }}"
        File.write(input, template)

        from_file = run_cli(["-i", input, "-o", output], env: {"FOO" => "bar"})
        from_stdout = run_cli(["-i", input], env: {"FOO" => "bar"})

        expect(from_file.exit_code).to eq 0
        expect(File.read(output)).to eq from_stdout.stdout
      end
    end

    it "reads from --in and writes to STDOUT" do
      with_tmp_dir do |dir|
        input = File.join(dir, "in.j2")
        File.write(input, "{{ env('FOO') }}")

        result = run_cli(["-i", input], env: {"FOO" => "bar"})

        expect(result.stdout).to eq "bar"
        expect(result.exit_code).to eq 0
      end
    end
  end

  # Regression guard for the runtime `CRYSTAL_ENV` gate that used to make the
  # binary a silent no-op (rendering nothing and exiting 0).
  describe "environment independence" do
    it "renders normally whatever CRYSTAL_ENV holds" do
      ["test", "development", "production", "staging", ""].each do |value|
        result = run_cli(input: "Hello {{ FOO }}", env: {"FOO" => "bar", "CRYSTAL_ENV" => value})

        expect({value, result.stdout}).to eq({value, "Hello bar"})
        expect({value, result.exit_code}).to eq({value, 0})
      end
    end
  end

  describe "exit codes" do
    it "exits 0 and prints the version with --version" do
      result = run_cli(["--version"])

      expect(result.exit_code).to eq 0
      expect(result.stdout).to contain Envtpl::VERSION
    end

    it "exits 0 and prints the usage with --help" do
      result = run_cli(["--help"])

      expect(result.exit_code).to eq 0
      expect(result.stdout).to contain "Usage: envtpl"
    end

    # No input is given: like --version, --licenses answers without waiting
    # for a template on STDIN.
    it "exits 0 and prints the embedded notices with --licenses" do
      result = run_cli(["--licenses"])

      expect(result.exit_code).to eq 0
      expect(result.stdout).to start_with "==> clib-Apache-2.0.txt <==\nUsed by: crystal\n"
      expect(result.stdout).to contain "\n\n==> crinja.txt <==\nCopyright 2017 Johannes Müller\n"
      expect(result.stdout).to contain "\n\n==> envtpl.txt <==\nThe MIT License (MIT)\n"
      expect(result.stderr).to eq ""
    end

    it "lists --licenses in the usage" do
      result = run_cli(["--help"])

      expect(result.stdout).to contain "--licenses"
    end

    it "exits 1 on an unknown option" do
      result = run_cli(["--nope"])

      expect(result.exit_code).to eq 1
      expect(result.stderr).to contain "is not a valid option"
    end

    it "exits 1 when the input file does not exist" do
      result = run_cli(["-i", "/nonexistent/envtpl-spec.j2"])

      expect(result.exit_code).to eq 1
      expect(result.stderr).to contain "Input file is not readable"
    end

    it "exits 1 on a template syntax error" do
      result = run_cli(input: "{{ unclosed ")

      expect(result.exit_code).to eq 1
    end

    # A rendering failure must never truncate an existing destination file.
    it "leaves --out untouched when rendering fails" do
      with_tmp_dir do |dir|
        input = File.join(dir, "in.j2")
        output = File.join(dir, "out.txt")
        File.write(input, "{{ unclosed ")
        File.write(output, "previous content")

        result = run_cli(["-i", input, "-o", output])

        expect(result.exit_code).to eq 1
        expect(File.read(output)).to eq "previous content"
      end
    end
  end

  describe "error reporting" do
    it "names the input file in template errors instead of <string>" do
      with_tmp_dir do |dir|
        input = File.join(dir, "broken.j2")
        File.write(input, "{{ unclosed ")

        result = run_cli(["-i", input, "-o", File.join(dir, "out.txt")])

        expect(result.stderr).to contain "broken.j2"
        expect(result.stderr).not_to contain "<string>"
      end
    end

    it "reports the exception class alongside the message" do
      result = run_cli(input: "{{ unclosed ")

      expect(result.stderr).to contain "Crinja::"
    end
  end

  describe "--strict" do
    it "renders an undefined variable as an empty string by default" do
      result = run_cli(input: "[{{ NO_SUCH_VAR }}]")

      expect(result.stdout).to eq "[]"
      expect(result.exit_code).to eq 0
    end

    it "fails on an undefined variable, naming it in the message" do
      result = run_cli(["--strict"], input: "[{{ NO_SUCH_VAR }}]")

      expect(result.exit_code).to eq 1
      expect(result.stderr).to contain "NO_SUCH_VAR is undefined"
    end

    it "still honours the default filter" do
      result = run_cli(["--strict"], input: "{{ NO_SUCH_VAR | default('fallback') }}")

      expect(result.stdout).to eq "fallback"
      expect(result.exit_code).to eq 0
    end

    it "still honours the defined test" do
      result = run_cli(["--strict"], input: "{% if NO_SUCH_VAR is defined %}yes{% else %}no{% endif %}")

      expect(result.stdout).to eq "no"
      expect(result.exit_code).to eq 0
    end

    it "does not fail on a variable that is defined" do
      result = run_cli(["--strict"], input: "{{ FOO }}", env: {"FOO" => "bar"})

      expect(result.stdout).to eq "bar"
      expect(result.exit_code).to eq 0
    end
  end
end
