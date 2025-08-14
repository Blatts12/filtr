# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Elixir library project named "Pex" that parses query parameters in Phoenix controllers and LiveViews by defining schemas that will be validated using custom validators. The project uses the decorator package to add schema per controller.

## Common Commands

### Building and Testing
- `mix compile` - Compile the project
- `mix test` - Run all tests
- `mix test test/pex_test.exs` - Run a specific test file
- `mix deps.get` - Fetch dependencies
- `mix deps.compile` - Compile dependencies

### Development
- `iex -S mix` - Start an interactive Elixir session with the project loaded
- `mix format` - Format code according to Elixir standards
- `mix dialyzer` - Run static analysis (if Dialyzer is added as dependency)
- `mix docs` - Generate documentation (if ExDoc is added as dependency)

### Testing
- `mix test --trace` - Run tests with detailed output
- `mix test --cover` - Run tests with coverage report

## Code Architecture

### Structure
- `lib/pex.ex` - Main module containing the public API
- `test/pex_test.exs` - Test suite for the main module
- `test/test_helper.exs` - Test configuration
- `mix.exs` - Project configuration and dependencies

### Architecture Overview
The project implements query parameter parsing and validation for Phoenix applications:
- Schemas define the structure and validation rules for query parameters
- Custom validators ensure data integrity and format compliance
- Decorator package integration allows attaching schemas to individual controllers
- Works seamlessly with both Phoenix controllers and LiveViews

### Key Components
- Parameter schema definitions with type validation
- Custom validator implementations
- Controller decorator integration for automatic parsing
- Phoenix/LiveView integration layer

## Notes
- Elixir version requirement: ~> 1.18
- Project uses standard Mix project structure
- Tests include both unit tests and doctests