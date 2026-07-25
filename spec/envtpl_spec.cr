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
      end
    end
  end
end
