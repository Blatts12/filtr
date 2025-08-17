# Pex

A powerful Elixir library for parsing and validating query parameters in Phoenix controllers and LiveViews using declarative schemas with custom validators.

## Features

- 🔍 **Declarative Schemas** - Define parameter validation rules using simple maps
- ✅ **Type Casting** - Automatic conversion between string parameters and Elixir types
- 🛡️ **Custom Validators** - Built-in validators plus support for custom validation functions
- 🎯 **Decorator Integration** - Clean controller annotations using the decorator package
- 🚀 **Phoenix Integration** - Seamless integration with Phoenix controllers and LiveViews
- 📊 **Comprehensive Error Handling** - Detailed error messages for validation failures
- 🛟 **No-Error Mode** - Graceful fallback where invalid values become defaults or nil

## Installation

Add `pex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pex, "~> 0.1.0"}
  ]
end
```
