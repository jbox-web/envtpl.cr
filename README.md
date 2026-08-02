# envtpl

`envtpl` is [envtpl](https://github.com/envtpl/envtpl) in [Crystal](https://crystal-lang.org/)

`envtpl` renders [Crinja](https://github.com/straight-shoota/crinja) templates on the command line using environment variables.

## Installation

Grab the latest binary from the [releases](https://github.com/jbox-web/envtpl.cr/releases) page and run it :)

## Usage

```sh
Usage: envtpl [arguments]
    -i FILE, --in=FILE               Specifies the input file (STDIN by default)
    -o FILE, --out=FILE              Specifies the output file (STDOUT by default)
    -s, --strict                     Fail instead of rendering an empty string for an undefined variable
    -v, --version                    Show version
    -h, --help                       Show this help
```

The template is rendered verbatim: whether it goes to STDOUT or to `--out`, the
output is byte for byte the same, trailing newline included.

## Examples

### Reading a variable

Any environment variable is available under its own name:

```sh
$ echo "Hello: {{ SHELL }}" | envtpl
Hello: /bin/bash
```

The `env()` function does the same and also works for names that are not valid
template identifiers (`{{ MY-VAR }}` does not parse, `{{ env('MY-VAR') }}` does):

```sh
$ echo "Hello: {{ env('SHELL') }}" | envtpl
Hello: /bin/bash
```

Called with several names, it returns a hash restricted to them, skipping the
ones that are not set:

```sh
$ echo "Hello: {{ env('SHELL', 'USER') }}" | envtpl
Hello: {'SHELL' => '/bin/bash', 'USER' => 'nicolas'}
```

Called with no argument at all, it returns the **whole** environment. Mind that
this includes every secret the process was given:

```sh
$ echo "{{ env() }}" | envtpl
{'SHELL' => '/bin/bash', 'USER' => 'nicolas', ...}
```

### Missing variables

An undefined variable renders as an empty string, so a typo silently produces an
empty value:

```sh
$ echo "[{{ NO_SUCH_VAR }}]" | envtpl
[]
```

Use `default=` to make the fallback explicit:

```sh
$ echo "{{ env('NO_SUCH_VAR', default='fallback') }}" | envtpl
fallback
```

…or `--strict` to turn the whole thing into an error. `default()` and
`is defined` keep working under `--strict`; only *rendering* an undefined
variable fails:

```sh
$ echo "[{{ NO_SUCH_VAR }}]" | envtpl --strict
Crinja::UndefinedError: NO_SUCH_VAR is undefined.
template: <stdin>:1:2 .. 1:19

 1 | [{{ NO_SUCH_VAR }}]
 X |  ^~~~~~~~~~~~~~~~~
$ echo $?
1
```

### The `json` filter

Serialises any value as JSON, indented by two spaces unless told otherwise:

```sh
$ echo "{{ env('SHELL', 'USER') | json }}" | envtpl
{
  "SHELL": "/bin/bash",
  "USER": "nicolas"
}

$ echo "{{ env('SHELL', 'USER') | json(indent=4) }}" | envtpl
{
    "SHELL": "/bin/bash",
    "USER": "nicolas"
}
```

### A note on template trust

Templates are executable input: `{% include 'other.j2' %}` reads any file under
the current working directory (absolute paths and `../` traversal are refused).
Render templates you trust.

## Contributing

1. Fork it (<https://github.com/jbox-web/envtpl.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Nicolas Rodriguez](https://github.com/n-rodriguez) - creator and maintainer

## Similar Tools

* https://github.com/envtpl/envtpl (Python)
* https://github.com/subfuzion/envtpl (Go)
* https://github.com/mattrobenolt/envtpl (Go)
* https://github.com/arschles/envtpl (Go)
* https://github.com/niquola/envtpl (Rust)
