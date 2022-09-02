require "./spec_helper"

Spectator.describe Envtpl do
  before_each { ENV["FOO"] = "foo value" }
  after_each { ENV.delete("FOO") }

  describe ".transform" do
    describe "variable style rendering" do
      it "renders template" do
        output = Envtpl.transform("{{ FOO }}")
        expect(output).to eq "foo value"
      end

      it "can be piped to other functions" do
        output = Envtpl.transform("{{ FOO | capitalize }}")
        expect(output).to eq "Foo value"
      end

      context "when the key does not exist" do
        it "renders template" do
          output = Envtpl.transform("{{ bar | default('world') }}")
          expect(output).to eq "world"
        end
      end
    end

    describe "functions" do
      describe "env()" do
        context "with no arguments" do
          it "renders all environment variables as a hash" do
            output = Envtpl.transform("{{ env() }}")
            expected = ENV.to_h.to_s.gsub("\"", "'")

            expect(output).to eq expected
          end

          it "can be piped to other functions" do
            output = Envtpl.transform("{{ env() | json }}")
            output = Hash(String, String).from_json(output).to_json
            expected = ENV.to_h.to_json
            expect(output).to eq expected
          end
        end

        context "with no arguments and [] accessor" do
          it "renders a single value" do
            output = Envtpl.transform("{{ env()['FOO'] }}")
            expect(output).to eq "foo value"
          end

          context "when the key does not exist" do
            it "raises an error" do
              expect { Envtpl.transform("{{ env()['baz'] }}") }.to raise_error
            end
          end
        end

        context "with one string argument" do
          it "renders a single value" do
            output = Envtpl.transform("{{ env('FOO') }}")
            expect(output).to eq "foo value"
          end

          context "when the key does not exist" do
            it "renders an empty value" do
              output = Envtpl.transform("{{ env('baz') }}")
              expect(output).to eq ""
            end

            it "renders a default value" do
              output = Envtpl.transform("{{ env('baz', default='world') }}")
              expect(output).to eq "world"
            end
          end

          it "can be piped to other functions" do
            output = Envtpl.transform("{{ env('FOO') | capitalize }}")
            expect(output).to eq "Foo value"
          end
        end

        context "with multi string arguments" do
          it "renders environment variables as a hash" do
            ENV["BAR"] = "BAZ"
            output = Envtpl.transform("{{ env('FOO', 'BAR') }}")
            expect(output).to eq "{'FOO' => 'foo value', 'BAR' => 'BAZ'}"
            ENV.delete("BAR")
          end

          context "when multi string arguments contains non existent keys" do
            it "renders environment variables as a hash and skip non-existent keys" do
              output = Envtpl.transform("{{ env('FOO', 'BAR') }}")
              expect(output).to eq "{'FOO' => 'foo value'}"
            end
          end
        end
      end
    end
  end
end
