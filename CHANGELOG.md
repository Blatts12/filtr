# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-09-18

### Breaking changes

- Schema entries are maps (`%{type: ...}`) instead of keyword lists
- `:required` and `:default` moved out of `:validators` onto the field map
- Nested schemas are wrapped under `:type` (`%{type: %{...}}`)
- Plugin callbacks receive a context map as their last argument instead of an opts keyword list

### Changed

- Extract processing into a `Filtr.Processor` pipeline and a central `Filtr.Types` module
- `Filtr.Helpers.parse_param_opts/1` returns a map and reads `:type`, `:default`, `:required`,
  `:error_mode` as top-level keys

### Performance

- ~32% faster processing and ~40% less memory on average, see `benchmark/results.md`

### Migration

Macro DSL only (`param :name, :string, ...`)? Recompiling is enough. Hand-built schema maps
passed to `Filtr.run/2,3` and custom plugins need the changes below.

| Concept         | v1                                              | v2                                                 |
| --------------- | ----------------------------------------------- | -------------------------------------------------- |
| Field           | `[type: :string]`                               | `%{type: :string}`                                 |
| Required        | `[type: :string, validators: [required: true]]` | `%{type: :string, required: true, validators: []}` |
| Default         | `[type: :integer, validators: [default: 0]]`    | `%{type: :integer, default: 0, validators: []}`    |
| Validators      | `[type: :integer, validators: [min: 18]]`       | `%{type: :integer, validators: [min: 18]}`         |
| Nested schema   | `%{user: %{name: [type: :string]}}`             | `%{user: %{type: %{name: %{type: :string}}}}`      |
| List of scalars | `[type: {:list, :string}]`                      | `%{type: {:list, :string}}`                        |
| List of schemas | `[type: {:list, %{...}}]`                       | `%{type: {:list, %{...}}}`                         |

Anything that is not `:type`, `:default`, `:required`, or `:error_mode` stays in `:validators`.
Plugin `cast/3` and `validate/4` get the context map as their last argument now, so read
`params`, `key`, `error_mode` or `opts` from it instead of an opts keyword (see
`Filtr.Processor.Context`).

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

[Unreleased]: https://github.com/Blatts12/filtr/compare/1.0.1...HEAD
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
