# envtpl

`envtpl` is [envtpl](https://github.com/envtpl/envtpl) in [Crystal](https://crystal-lang.org/)

`envtpl` renders [Crinja](https://github.com/straight-shoota/crinja) templates on the command line using environment variables.

## Installation

Grab the latest binary from the [releases](https://github.com/jbox-web/envtpl/releases) page and run it :)

## Usage

```sh
Usage: envtpl [arguments]
    -i FILE, --in=FILE               Specifies the input file (STDIN by default)
    -o FILE, --out=FILE              Specifies the output file (STDOUT by default)
    -h, --help                       Show this help
```

## Examples

```sh
nicolas@laptop:~/PROJECTS/CRYSTAL/envtpl$ echo "Hello: {{ SHELL }}" | bin/envtpl
Hello: /bin/bash
```

```sh
nicolas@laptop:~/PROJECTS/CRYSTAL/envtpl$ echo "Hello: {{ env('SHELL') }}" | bin/envtpl
Hello: /bin/bash
```

```sh
nicolas@laptop:~/PROJECTS/CRYSTAL/envtpl$ echo "Hello: {{ env('SHELL', 'USER') }}" | bin/envtpl
Hello: {'SHELL' => '/bin/bash', 'USER' => 'nicolas'}
```

## Contributing

1. Fork it (<https://github.com/your-github-user/envtpl/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Nicolas Rodriguez](https://github.com/your-github-user) - creator and maintainer

## Similar Tools

* https://github.com/envtpl/envtpl (Python)
* https://github.com/subfuzion/envtpl (Go)
* https://github.com/mattrobenolt/envtpl (Go)
* https://github.com/arschles/envtpl (Go)
* https://github.com/niquola/envtpl (Rust)
