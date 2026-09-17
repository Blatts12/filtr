# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

> These changes are slated for the **2.0.0** release.

### Breaking changes

- **Schema entries are now maps instead of keyword lists.** Every field maps to a
  `%{type: ...}` map rather than a `[type: ...]` keyword list.
- **`:required` and `:default` are top-level keys.** They were moved out of the
  `:validators` list onto the field map itself.
- **Nested schemas are wrapped under `:type`.** A nested schema is now the value of a
  `:type` key (`%{type: %{...}}`) instead of being assigned directly to the field.
- **Plugin callbacks receive a context map** as their last argument instead of an opts
  keyword list. Custom plugins that read from the old opts keyword must be updated.

### Changed

- The processing logic was extracted from `Filtr` into a dedicated `Filtr.Processor`
  pipeline (`Cast`, `Validate`, `Value`, `Context`, `Default`, `Error`, `Opaque`) plus a
  central `Filtr.Types` module. `Filtr.run/3` now delegates to `Filtr.Processor.run/3`.
- `Filtr.Helpers.parse_param_opts/1` now returns a map (was a keyword list) and recognizes
  `:type`, `:default`, `:required`, and `:error_mode` as top-level keys, grouping everything
  else under `:validators`.
- The per-key hot path does less work. `Filtr.run/3` no longer pre-seeds the plugin map into
  the run opts, since `Filtr.Processor.Context` already resolves it lazily. The context keeps
  the opts keyword as it arrives instead of rebuilding it twice. Schema and plugin lookups for
  `:type`, `:required`, `:validators`, `:default`, and `:error_mode` are function-head matches
  now, not `Map.get/3` and `Access` calls.

### Performance

The v2 schema/processor refactor - map-based schema entries, top-level `:required` / `:default`, and the dedicated `Filtr.Processor` pipeline - cut the
bulk of the time and memory, with the largest gains on nested and list-heavy schemas. A
follow-up pass over the per-key hot path removed the remaining `Map.get/3` and `Access`
dispatch, which is worth another 10% or so on short schemas and up to 20% on single-value
casts. Measured on an AMD Ryzen 7 5800X (Elixir 1.20.1 / Erlang 29.0.2). See
`benchmark/results.md` for full numbers.

**Faster processing**

| Workload                              | Before   | After   | Change      |
| ------------------------------------- | -------- | ------- | ----------- |
| Full mixed-schema run (all types)     | 6.45 μs  | 4.29 μs | ~33% faster |
| Nested schema, depth 10               | 2.21 μs  | 1.61 μs | ~27% faster |
| Nested schema, depth 50               | 9.21 μs  | 6.19 μs | ~33% faster |
| List of nested schemas, depth 10      | 3.06 μs  | 2.04 μs | ~33% faster |
| List of nested schemas, depth 50      | 13.81 μs | 8.48 μs | ~39% faster |
| `collect_errors/1` (list of 100 maps) | 6.43 μs  | 7.23 μs | ~12% slower |
| Boolean cast                          | 496 ns   | 304 ns  | ~39% faster |
| Per-type validator suite (e.g. list)  | 858 ns   | 700 ns  | ~18% faster |

**Lower memory usage**

| Workload                          | Before   | After    | Change    |
| --------------------------------- | -------- | -------- | --------- |
| Full mixed-schema run (all types) | 12 KB    | 6.30 KB  | ~48% less |
| Nested schema, depth 10           | 5.23 KB  | 3.41 KB  | ~35% less |
| Nested schema, depth 50           | 22.78 KB | 14.38 KB | ~37% less |
| List of nested schemas, depth 10  | 7.06 KB  | 4.64 KB  | ~34% less |
| List of nested schemas, depth 50  | 32.38 KB | 21.20 KB | ~35% less |
| String, full validator set        | 1672 B   | 944 B    | ~44% less |
| Boolean cast                      | 792 B    | 360 B    | ~55% less |
| Integer, full validator set       | 832 B    | 512 B    | ~38% less |
| Plugin dispatch                   | 656 B    | 384 B    | ~41% less |

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
