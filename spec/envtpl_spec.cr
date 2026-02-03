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
          it "renders all environment variables as a hash" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env() }}")
              expected = ENV.to_h.to_s.gsub("\"", "'")

              expect(output).to eq expected
            end
          end

          it "can be piped to other functions" do
            with_env("FOO": "foo value") do
              output = Envtpl.transform("{{ env() | json }}")
              output = Hash(String, String).from_json(output).to_json
              expected = ENV.to_h.to_json
              expect(output).to eq expected
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
