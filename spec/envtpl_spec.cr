require "./spec_helper"

Spectator.describe Envtpl do
  describe ".transform" do
    describe "variable style rendering" do
      it "renders template" do
        with_env("FOO": "foo value") do
          output = Envtpl.transform("{{ FOO }}")
          expect(output).to eq "foo value"
        end
      end

      it "can be piped to other functions" do
        with_env("FOO": "foo value") do
          output = Envtpl.transform("{{ FOO | capitalize }}")
          expect(output).to eq "Foo value"
        end
      end

      context "when the key does not exist" do
        it "renders template" do
          with_env("FOO": "foo value") do
            output = Envtpl.transform("{{ bar | default('world') }}")
            expect(output).to eq "world"
          end
        end
      end
    end

    describe "functions" do
      describe "env()" do
        context "with no arguments" do
          # The assertions below deliberately never interpolate an environment
          # *value* into an expectation: a failure would then print the whole
          # environment (secrets included) to the CI logs. Only key names and
          # the value we set ourselves are ever compared.
          it "renders all environment variables as a hash" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env() }}")

              expect(output.starts_with?("{")).to be_true
              expect(output.ends_with?("}")).to be_true
              expect(output.includes?("'FOO' => 'foo value'")).to be_true

              missing_keys = ENV.to_h.keys.reject { |key| output.includes?("'#{key}' => ") }
              expect(missing_keys).to be_empty
            end
          end

          it "can be piped to other functions" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env() | json }}")
              parsed = Hash(String, String).from_json(output)

              expect(parsed["FOO"]?).to eq "foo value"

              missing_keys = ENV.to_h.keys.reject { |key| parsed.has_key?(key) }
              expect(missing_keys).to be_empty

              mismatched_keys = ENV.to_h.compact_map { |key, value| key if parsed[key]? != value }
              expect(mismatched_keys).to be_empty
            end
          end
        end

        context "with no arguments and [] accessor" do
          it "renders a single value" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env()['FOO'] }}")
              expect(output).to eq "foo value"
            end
          end

          context "when the key does not exist" do
            it "raises an error" do
              with_env("FOO": "foo value") do
                expect { Envtpl.transform("{{ env()['baz'] }}") }.to raise_error
              end
            end
          end
        end

        context "with one string argument" do
          it "renders a single value" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env('FOO') }}")
              expect(output).to eq "foo value"
            end
          end

          context "when the key does not exist" do
            it "renders an empty value" do
              with_env("FOO": "foo value") do
                output = Envtpl.transform("{{ env('baz') }}")
                expect(output).to eq ""
              end
            end

            it "renders a default value" do
              with_env("FOO": "foo value") do
                output = Envtpl.transform("{{ env('baz', default='world') }}")
                expect(output).to eq "world"
              end
            end
          end

          it "can be piped to other functions" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env('FOO') | capitalize }}")
              expect(output).to eq "Foo value"
            end
          end
        end

        context "with multi string arguments" do
          it "renders environment variables as a hash" do
            with_env("FOO": "foo value", "BAR": "BAZ") do
              output = Envtpl.transform("{{ env('FOO', 'BAR') }}")
              expect(output).to eq "{'FOO' => 'foo value', 'BAR' => 'BAZ'}"
            end
          end

          context "when multi string arguments contains non existent keys" do
            it "renders environment variables as a hash and skip non-existent keys" do
              with_env("FOO": "foo value") do
                output = Envtpl.transform("{{ env('FOO', 'BAR') }}")
                expect(output).to eq "{'FOO' => 'foo value'}"
              end
            end
          end
        end

        context "with an explicit nil default" do
          it "renders an empty value rather than the literal 'none'" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env('baz', default=none) }}")
              expect(output).to eq ""
            end
          end
        end
      end
    end

    describe "filters" do
      describe "json" do
        it "indents with two spaces by default" do
          with_env("FOO": "foo value") do
            output = Envtpl.transform("{{ env('FOO') | json }}")
            expect(output).to eq %("foo value")
          end
        end

        it "honours an explicit indent" do
          with_env("FOO": "1", "BAR": "2") do
            output = Envtpl.transform("{{ env('FOO', 'BAR') | json(indent=4) }}")
            expect(output).to eq %({\n    "FOO": "1",\n    "BAR": "2"\n})
          end
        end

        it "escapes characters that would break the output syntax" do
          with_env("FOO": %(he said "hi")) do
            output = Envtpl.transform("{{ env('FOO') | json }}")
            expect(output).to eq %("he said \\"hi\\"")
          end
        end

        # A non-numeric indent is a template author mistake: it must not abort
        # the whole render with a bare `Invalid Int32`.
        context "when indent is not numeric" do
          it "falls back to the default indent" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env('FOO') | json(indent='zz') }}")
              expect(output).to eq %("foo value")
            end
          end
        end
      end
    end

    describe "trailing newline" do
      it "keeps the trailing newline of the template" do
        with_env("FOO": "foo value") do
          expect(Envtpl.transform("{{ FOO }}\n")).to eq "foo value\n"
        end
      end

      it "does not add a newline the template does not have" do
        with_env("FOO": "foo value") do
          expect(Envtpl.transform("{{ FOO }}")).to eq "foo value"
        end
      end
    end
  end

  describe ".version" do
    it "combines the shard version and the git ref" do
      expect(Envtpl.version).to eq "#{Envtpl::VERSION} (#{Envtpl::GIT_REF})"
    end
  end

  describe ".read" do
    it "reads the content of a file" do
      with_tmp_dir do |dir|
        path = File.join(dir, "in.j2")
        File.write(path, "{{ FOO }}\n")

        expect(Envtpl.read(path)).to eq "{{ FOO }}\n"
      end
    end
  end

  describe ".render" do
    it "writes the content to a file verbatim" do
      with_tmp_dir do |dir|
        path = File.join(dir, "out.txt")
        Envtpl.render("some content\n", path)

        expect(File.read(path)).to eq "some content\n"
      end
    end
  end

  describe ".convert" do
    it "renders a file into another file" do
      with_env("FOO": "foo value") do
        with_tmp_dir do |dir|
          input = File.join(dir, "in.j2")
          output = File.join(dir, "out.txt")
          File.write(input, "value: {{ FOO }}\n")

          Envtpl.convert(input, output)

          expect(File.read(output)).to eq "value: foo value\n"
        end
      end
    end

    it "leaves the destination untouched when rendering raises" do
      with_tmp_dir do |dir|
        input = File.join(dir, "in.j2")
        output = File.join(dir, "out.txt")
        File.write(input, "{{ unclosed ")
        File.write(output, "previous content")

        expect { Envtpl.convert(input, output) }.to raise_error
        expect(File.read(output)).to eq "previous content"
      end
    end
  end
end
