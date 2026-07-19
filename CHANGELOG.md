# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-07-04

- Fix nested schemas on latest Elixir version

## [1.0.0] - 2026-03-01 - Plugin Refactor

- Optimize cast process
- Simplify plugin system
- Other optimizations

## [0.4.0] - 2025-12-21

- Add support for function error mode in controllers

## [0.3.0] - 2025-11-22

- Logo
- Add support for nested schemata and list with nested schema in `param` macro
- Fix parsing of list of maps in `run` function
- Import `collect_errors` function in `use Filtr.Controller/LiveView`
- Remove `_valid?` field from nested schemas

## [0.2.1] - 2025-11-09

- Add `_valid?` field to returned data from `run/3`

## [0.2.0] - 2025-11-06

- Fix check for invalid error_mode
- Merge validators and run opts in `param` macro

## [0.1.7] - 2025-10-31

- Refactor plugin system chaining

## [0.1.6] - 2025-10-30

- Add function to collect all errors in strict mode

## [0.1.5] - 2025-10-27

- Use `persistent_term` to cache plugin type map

## [0.1.4] - 2025-10-26

- Documentation improvements

## [0.1.0] - 2025-10-26 - First Release

- Initial release

[1.0.1]: https://github.com/Blatts12/filtr/releases/tag/1.0.1
[1.0.0]: https://github.com/Blatts12/filtr/releases/tag/1.0.0
[0.4.0]: https://github.com/Blatts12/filtr/releases/tag/0.4.0
[0.3.0]: https://github.com/Blatts12/filtr/releases/tag/0.3.0
[0.2.1]: https://github.com/Blatts12/filtr/releases/tag/0.2.1
[0.2.0]: https://github.com/Blatts12/filtr/releases/tag/0.2.0
[0.1.7]: https://github.com/Blatts12/filtr/releases/tag/0.1.7
[0.1.6]: https://github.com/Blatts12/filtr/releases/tag/0.1.6
[0.1.5]: https://github.com/Blatts12/filtr/releases/tag/0.1.5
[0.1.4]: https://github.com/Blatts12/filtr/releases/tag/0.1.4
[0.1.0]: https://github.com/Blatts12/filtr/releases/tag/0.1.0
