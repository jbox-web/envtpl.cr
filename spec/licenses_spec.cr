require "./spec_helper"

# Not loaded by the library (see src/cli.cr), hence the explicit require.
require "../src/envtpl/licenses"

Spectator.describe Envtpl::Licenses do
  # The list follows licenses.manifest: the LICENSE of the runtime shard, the
  # upstream text of each C library whose license carries a notice of its own,
  # one grouped file per SPDX id for the others, plus the project's own
  # LICENSE. An empty or partial list means the harvest did not run before
  # compilation.
  it "embeds the notices of the manifest plus the project license" do
    expect(Envtpl::Licenses::FILES.keys).to eq([
      "clib-Apache-2.0.txt",
      "clib-Boehm-GC.txt",
      "clib-GCC-runtime-exception.txt",
      "crinja.txt",
      "envtpl.txt",
      "liblzma.txt",
      "libxml2.txt",
      "musl.txt",
      "pcre2.txt",
      "zlib.txt",
    ])
  end

  it "records which libraries each grouped notice covers" do
    files = Envtpl::Licenses::FILES
    expect(files["clib-Apache-2.0.txt"]).to start_with("Used by: crystal\n")
    expect(files["clib-Boehm-GC.txt"]).to start_with("Used by: boehm-gc\n")
    expect(files["clib-GCC-runtime-exception.txt"]).to start_with("Used by: libgcc\n")
  end

  # The GCC Runtime Library Exception 3.1 is an additional permission of the
  # GPLv3: libgcc is GPL-3.0-or-later WITH that exception, never GPL-2.0.
  it "names the license the GCC runtime exception applies to" do
    notice = Envtpl::Licenses::FILES["clib-GCC-runtime-exception.txt"]
    expect(notice).to contain("libgcc is distributed under GPL-3.0-or-later WITH the following exception")
    expect(notice).not_to contain("GPL-2.0")
  end

  # MIT, BSD and zlib all require the copyright notice to be reproduced: the
  # notice of the library, not the blank of a license template.
  it "carries the copyright notice of each library, as its authors wrote it" do
    files = Envtpl::Licenses::FILES
    expect(files["crinja.txt"]).to contain("Copyright 2017 Johannes Müller")
    expect(files["envtpl.txt"]).to contain("Copyright (c) 2022-2026 Nicolas Rodriguez")
    expect(files["libxml2.txt"]).to contain("Copyright (C) 1998-2012 Daniel Veillard.")
    expect(files["musl.txt"]).to contain("Copyright © 2005-2020 Rich Felker, et al.")
    expect(files["pcre2.txt"]).to contain("University of Cambridge")
    expect(files["zlib.txt"]).to contain("Jean-loup Gailly and Mark Adler")
  end

  it "embeds no license template with its blanks left in" do
    Envtpl::Licenses::FILES.each_value do |text|
      expect(text).not_to match(/<year>|<owner>|<copyright holders>|YEAR by AUTHOR/)
    end
  end

  # What `envtpl --licenses` prints: every notice, each under a header that
  # names its file, separated by a blank line.
  describe ".text" do
    it "prints each notice under a header naming its file, in order" do
      text = Envtpl::Licenses.text
      expect(text).to start_with("==> clib-Apache-2.0.txt <==\nUsed by: crystal\n")
      expect(text).to contain("\n\n==> clib-Boehm-GC.txt <==\n")
      expect(text.scan(/^==> [^\n]+ <==$/m).map(&.[0])).to eq([
        "==> clib-Apache-2.0.txt <==",
        "==> clib-Boehm-GC.txt <==",
        "==> clib-GCC-runtime-exception.txt <==",
        "==> crinja.txt <==",
        "==> envtpl.txt <==",
        "==> liblzma.txt <==",
        "==> libxml2.txt <==",
        "==> musl.txt <==",
        "==> pcre2.txt <==",
        "==> zlib.txt <==",
      ])
    end
  end
end
