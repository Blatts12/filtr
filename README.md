
![Filtr logo](./assets/logo.png)

Parameter validation library for Elixir with Phoenix integration.

Filtr provides a flexible, plugin-based system for validating and casting parameters in Phoenix applications. It offers seamless integration with Phoenix Controllers and LiveViews using an attr-style syntax similar to Phoenix Components.

## Features

- **Phoenix Integration**
- **Plugin System**
- **Nested Schemas**
- **Multiple Error Modes**
- **Zero Dependencies**
- **Phoenix Component's attr-like `param` macro**

## Requirements

- Elixir ~> 1.16
- Phoenix >= 1.6.0 (optional, for Controller/LiveView integration)
- Phoenix LiveView >= 0.20.0 (optional, for LiveView integration)

## Installation

Add `filtr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:filtr, "~> 0.2.0"}
  ]
end
```

### Formatter

To ensure proper formatting of the `param` macro, add `:filtr` to your `.formatter.exs` configuration:

```elixir
[import_deps: [:filtr]]
```

## Quick Start

### Phoenix Controller

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Filtr.Controller, error_mode: :raise

  param :name, :string, required: true
  param :age, :integer, min: 18, max: 120
  param :email, :string, required: true, pattern: ~r/@/

  def create(conn, params) do
    # params.name is guaranteed to be a string
    # params.age is guaranteed to be an integer between 18 and 120
    # params.email is guaranteed to be a string containing "@"
    json(conn, %{message: "User #{params.name} created"})
  end

  param :q, :string, default: ""
  param :page, :integer, default: 1, min: 1
  param :category, :string, in: ["books", "movies", "music"], default: "books"

  def search(conn, params) do
    # params.q defaults to ""
    # params.page defaults to 1 and is >= 1
    # params.category is one of the allowed values
    json(conn, %{query: params.q, page: params.page})
  end
end
```

### Phoenix LiveView

```elixir
defmodule MyAppWeb.SearchLive do
  use MyAppWeb, :live_view
  use Filtr.LiveView, error_mode: :raise

  param :query, :string, required: true, min: 1
  param :limit, :integer, default: 10, min: 1, max: 100

  def mount(_params, _session, socket) do
    # socket.assigns.filtr contains validated params
    # socket.assigns.filtr.query - validated query string
    # socket.assigns.filtr.limit - validated limit (defaults to 10)
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    # Params are automatically revalidated on navigation
    {:noreply, socket}
  end
end
```

### Standalone Usage

```elixir
schema = %{
  name: [type: :string, validators: [required: true, min: 2]],
  age: [type: :integer, validators: [min: 18, max: 120]],
  tags: [type: {:list, :string}, validators: [max: 5]]
}

params = %{
  "name" => "John Doe",
  "age" => "25",
  "tags" => ["elixir", "phoenix"]
}

result = Filtr.run(schema, params, error_mode: :raise)
# %{name: "John Doe", age: 25, tags: ["elixir", "phoenix"]}
```

## Error Modes

Filtr supports three error handling modes:

### Fallback Mode (Default)

Returns default values or nil on validation errors:

```elixir
schema = %{age: [type: :integer, validators: [default: 18]]}
params = %{"age" => "invalid"}

Filtr.run(schema, params, error_mode: :fallback)
# %{age: 18}
```

### Strict Mode

Returns error tuples for invalid values:

```elixir
schema = %{age: [type: :integer, validators: [min: 18]]}
params = %{"age" => "10"}

Filtr.run(schema, params, error_mode: :strict)
# %{age: {:error, ["must be at least 18"]}}
```

### Raise Mode

Raises exceptions on validation errors:

```elixir
schema = %{name: [type: :string, validators: [required: true]]}
params = %{}

Filtr.run(schema, params, error_mode: :raise)
# ** (RuntimeError) Invalid value for name: required
```

### Global Configuration

Set a default error mode in your config:

```elixir
# config/config.exs
config :filtr, error_mode: :strict
```

Or specify per-module:

```elixir
use Filtr.Controller, error_mode: :strict
use Filtr.LiveView, error_mode: :raise
```

## Validation Status

Filtr automatically includes a `_valid?` field in the result map to indicate whether all parameters passed validation. This field is always present regardless of error mode.

```elixir
schema = %{
  name: [type: :string, validators: [required: true]],
  age: [type: :integer, validators: [min: 18]]
}

# Valid params
params = %{"name" => "John", "age" => "25"}
result = Filtr.run(schema, params, error_mode: :strict)
# %{name: "John", age: 25, _valid?: true}

# Invalid params
params = %{"age" => "10"}
result = Filtr.run(schema, params, error_mode: :strict)
# %{name: {:error, ["required"]}, age: {:error, [...]}, _valid?: false}
```

This makes it easy to check validation status without inspecting individual fields:

```elixir
defmodule MyAppWeb.UserController do
  use Filtr.Controller, error_mode: :strict

  param :name, :string, required: true
  param :email, :string, required: true, pattern: ~r/@/

  def create(conn, params) do
    if params._valid? do
      # All params are valid, proceed with creation
      json(conn, %{message: "User #{params.name} created"})
    else
      # Some params have errors, collect and return them
      errors = Filtr.collect_errors(params)
      conn
      |> put_status(:bad_request)
      |> json(%{errors: errors})
    end
  end
end
```

## Advanced Features

### Nested Schemas

```elixir
schema = %{
  user: %{
    name: [type: :string, validators: [required: true]],
    email: [type: :string, validators: [required: true]]
  },
  settings: %{
    theme: [type: :string, validators: [in: ["light", "dark"]]],
    notifications: [type: :boolean]
  }
}

params = %{
  "user" => %{
    "name" => "John",
    "email" => "john@example.com"
  },
  "settings" => %{
    "theme" => "dark",
    "notifications" => "true"
  }
}

result = Filtr.run(schema, params)
# %{
#   user: %{name: "John", email: "john@example.com"},
#   settings: %{theme: "dark", notifications: true}
# }
```

### List of Nested Schemas

```elixir
schema = %{
  items: [
    type: {
      :list,
      %{
        name: [type: :string],
        quantity: [type: :integer, validators: [min: 1]]
      }
    }
  ]
}
```

### Custom Cast Functions

```elixir
upcase_cast = fn value, _opts -> {:ok, String.upcase(value)} end

schema = %{name: [type: upcase_cast]}
params = %{"name" => "john"}

Filtr.run(schema, params)
# %{name: "JOHN"}
```

### Custom Validators

```elixir
# 1-arity function
email_validator = fn value ->
  if String.contains?(value, "@"), do: true, else: {:error, "invalid email"}
end

# 2-arity function (receives value and type)
length_validator = fn value, _type ->
  if String.length(value) > 5, do: :ok, else: :error
end

# 3-arity function (receives value, type, and opts)
custom_validator = fn value, _type, opts ->
  max_length = Keyword.get(opts, :max_length, 100)
  if String.length(value) <= max_length, do: :ok, else: {:error, "too long"}
end

schema = %{
  email: [type: :string, validators: [custom: email_validator]],
  name: [type: :string, validators: [custom: length_validator]],
  bio: [type: :string, validators: [custom: custom_validator], max_length: 500]
}
```

### Default Values

```elixir
param :page, :integer, default: 1
param :limit, :integer, default: 10
param :sort, :string, default: "created_at"

# Dynamic defaults with functions
param :timestamp, :integer, default: fn -> System.system_time(:second) end
param :uuid, :string, default: fn -> Ecto.UUID.generate() end
```

### Required Fields

```elixir
param :name, :string, required: true
param :email, :string, required: true, pattern: ~r/@/

# With default, required is basically skipped
param :role, :string, required: true, default: "user"
```

### Error Mode Per Field

You can override the error mode for individual fields, allowing fine-grained control over error handling:

```elixir
defmodule MyAppWeb.UserController do
  use Filtr.Controller, error_mode: :strict

  # Override for specific param - won't raise, will use fallback
  param :optional_field, :string, default: "", error_mode: :fallback
  param :required_field, :string, required: true  # Uses :strict from module

  def create(conn, params) do
    # params.optional_field will be "" if invalid or missing
    # params.required_field will be {:error, [...]} if invalid
  end
end
```

**Use cases:**
- **Critical fields** - Use `:raise` or `:strict` for fields that must be valid
- **Optional fields** - Use `:fallback` with defaults for non-critical data
- **Mixed validation** - Combine modes to handle different requirements in the same schema

### Type Passthrough

For parameters that don't need validation:

```elixir
schema = %{
  metadata: [type: nil],           # Passes through any value
  raw_data: [type: :__none__]      # Passes through any value
}
```

## Plugin System

Extend Filtr with custom types and validators:

```elixir
defmodule MyApp.MoneyPlugin do
  use Filtr.Plugin

  @impl true
  def types, do: [:money]

  @impl true
  def cast(value, :money, _opts) when is_binary(value) do
    # Remove currency symbols and parse
    cleaned = String.replace(value, ~r/[$,]/, "")

    case Float.parse(cleaned) do
      {amount, _} -> {:ok, trunc(amount * 100)} # Store as cents
      :error -> {:error, "invalid money format"}
    end
  end

  def cast(value, :money, _opts) when is_integer(value), do: {:ok, value}

  @impl true
  def validate(value, :money, {:min, min}, _opts) do
    if value >= min, do: :ok, else: {:error, "amount too small"}
  end

  def validate(value, :money, {:max, max}, _opts) do
    if value <= max, do: :ok, else: {:error, "amount too large"}
  end
end
```

Register the plugin in your config:

```elixir
# config/config.exs
config :filtr, plugins: [MyApp.MoneyPlugin]
```

Use your custom type:

```elixir
param :price, :money, min_amount: 100, max_amount: 100_000

# Accepts: "$12.99", "1,234.56", 1299 (as cents)
```

#### `types/0`

The `types/0` callback declares which types your plugin handles. This is a required callback that returns a list of atoms:

```elixir
@impl true
def types, do: [:money, :currency, :price]
```

Filtr uses this information to build a type-to-plugin mapping at runtime (cached in `:persistent_term` for performance). When processing a parameter, Filtr looks up which plugins support that type and tries them in order. The mapping is built on first use and cached for subsequent requests, giving near compile-time performance.

#### `cast/3`

The `cast/3` callback is an optional callback that converts raw parameter values into the desired type. It receives the value to cast, the type atom, and options:

```elixir
@impl true
def cast(value, :money, _opts) when is_binary(value) do
  cleaned = String.replace(value, ~r/[$,]/, "")

  case Float.parse(cleaned) do
    {amount, _} -> {:ok, trunc(amount * 100)}
    :error -> {:error, "invalid money format"}
  end
end

def cast(value, :money, _opts) when is_integer(value) do
  {:ok, value}
end
```

**Return values:**

- `{:ok, casted_value}` - Successfully casted the value
- `{:error, error_message}` - Single error message
- `{:error, [error1, error2, ...]}` - Multiple error messages

**Automatic fallthrough:**

When you use `Filtr.Plugin`, a catch-all clause is automatically added to your plugin at compile time using `@before_compile`. This means you **don't need to manually add catch-all clauses** - if your function pattern doesn't match, Filtr automatically returns `:not_handled` and tries the next plugin in the chain.

#### `validate/4`

The `validate/4` callback is an optional callback that validates a casted value against specific validation rules. It receives the value, type, validator tuple, and options:

```elixir
@impl true
def validate(value, :money, {:min, min}, _opts) do
  if value >= min, do: :ok, else: {:error, "amount too small"}
end

def validate(value, :money, {:max, max}, _opts) do
  if value <= max, do: :ok, else: {:error, "amount too large"}
end

def validate(value, :money, {:currency, currency}, _opts) do
  # Custom currency validation
  if valid_currency?(value, currency) do
    :ok
  else
    {:error, "invalid currency"}
  end
end
```

**Return values:**

- `:ok` or `true` or `{:ok, any()}` - Validation passed
- `:error` or `false` - Validation failed (returns generic "invalid value" error)
- `{:error, error_message}` - Validation failed with specific message

**Automatic fallthrough:**

The validator parameter is a tuple like `{:min, 100}` or `{:in, ["USD", "EUR"]}`. Your plugin only needs to implement validators it supports - if a validator isn't recognized, the automatic catch-all clause returns `:not_handled` and Filtr tries the next plugin in the chain.

### Plugin Priority

Plugins are processed in reverse order, with later plugins taking precedence:

```elixir
config :filtr, plugins: [PluginA, PluginB]

# PluginB is tried first, then PluginA, then DefaultPlugin
```

This allows you to override built-in types:

```elixir
defmodule MyApp.CustomStringPlugin do
  use Filtr.Plugin

  @impl true
  def types, do: [:string]

  @impl true
  def cast(value, :string, _opts) do
    # Custom string handling
    {:ok, String.trim(value)}
  end

  @impl true
  def validate(value, :string, validator, opts) do
    # Delegate to default string validators
    Filtr.DefaultPlugin.validate(value, :string, validator, opts)
  end
end
```

#### Cast and Validate Precedence

When multiple plugins support the same type, Filtr tries them in reverse order (later plugins first). If a plugin doesn't implement `cast/3` or `validate/4` for a specific case, or if the function clause doesn't match, Filtr automatically falls through to the next plugin in the chain.

**Example:**

```elixir
# config/config.exs
config :filtr, plugins: [PluginA, PluginB, PluginC]

# Filtr tries plugins in this order:
# 1. PluginC
# 2. PluginB
# 3. PluginA
# 4. DefaultPlugin (always last)
```

**How fallthrough works:**

When you `use Filtr.Plugin`, a `@before_compile` hook automatically adds catch-all clauses to your plugin that return `:not_handled` for any unmatched function patterns. This means you only need to implement the specific cases you care about:

```elixir
defmodule MyPlugin do
  use Filtr.Plugin

  @impl true
  def types, do: [:string]

  @impl true
  def cast(value, :string, _opts) when is_binary(value) do
    {:ok, String.trim(value)}
  end
  # No need to add: def cast(_value, _type, _opts), do: :not_handled
  # This is automatically added by @before_compile!

  @impl true
  # Only implement :min validator, others fall through
  def validate(value, :string, {:min, min}, _opts) do
    if String.length(value) >= min, do: :ok, else: {:error, "too short"}
  end
  # No need to add: def validate(_value, _type, _validator, _opts), do: :not_handled
  # This is automatically added by @before_compile!
end

# When using :max validator, it falls through to DefaultPlugin
param :name, :string, min: 2, max: 50
# :min uses MyPlugin, :max uses DefaultPlugin
```

This allows you to:

- Override specific validators while keeping others
- Add new validators to existing types
- Completely replace type handling when needed

### Default Plugin

Filtr includes a built-in `DefaultPlugin` that provides support for common data types. This plugin is always included and runs last in the plugin chain, so custom plugins can override its behavior.

#### Supported types

- `:string` - Text values
- `:integer` - Whole numbers (parses from strings)
- `:float` - Decimal numbers (parses from strings)
- `:boolean` - True/false values (accepts "true", "false", "1", "0", "yes", "no")
- `:date` - Date values (accepts Date structs, NaiveDateTime structs, DateTime structs, or ISO8601 strings)
- `:datetime` - DateTime values (accepts DateTime structs, NaiveDateTime structs, or ISO8601 strings)
- `:list` - List values (accepts arrays or comma-separated strings)

#### Available validators

**String validators:**

- `min: n` - Minimum length
- `max: n` - Maximum length
- `length: n` - Exact length
- `pattern: regex` - Must match regex pattern
- `starts_with: prefix` - Must start with prefix
- `ends_with: suffix` - Must end with suffix
- `contains: substring` - Must contain substring
- `alphanumeric: true` - Only letters and numbers
- `in: list` - Must be one of the listed values

**Integer/Float validators:**

- `min: n` - Minimum value
- `max: n` - Maximum value
- `positive: true` - Must be > 0
- `negative: true` - Must be < 0
- `in: list` - Must be one of the listed values

**Date/DateTime validators:**

- `min: date` - Must be after or equal to
- `max: date` - Must be before or equal to

**List validators:**

- `min: n` - Minimum number of items
- `max: n` - Maximum number of items
- `length: n` - Exact number of items
- `unique: true` - All items must be unique
- `non_empty: true` - List cannot be empty
- `in: list` - All items must be from the allowed list

You can always delegate to the DefaultPlugin from your custom plugins:

```elixir
@impl true
def validate(value, :upcase, validator, opts) do
  # Use default string validators
  Filtr.DefaultPlugin.validate(value, :string, validator, opts)
end

@impl true
def cast(value, :upcase, opts) do
  case Filtr.DefaultPlugin.cast(value, :string, opts) do
    {:ok, value} -> {:ok, String.upcase(value)}
    error -> error
  end
end
```

## TODO

- [x] Logo
- [ ] Docs in Code
- [ ] More Tests
- [ ] Benchmarks
- [ ] CI/CD
- [ ] Improve `README.md`
- [ ] Introduce `AGENTS.md` file
- [x] `_valid?` field for strict mode to know if params are valid
- [x] Move on from `try catch` to different approach for plugin chaining
- [x] Extract errors function for strict mode
- [ ] Custom error modes (return 400 error on fail in controllers?)
- [ ] Macro for nested schemas?

Proposal for nested schema macro
```elixir
param :user do
  param :uuid, :string
end

param :users, :list do
  param :uuid, :string
end
```

Distributed under the MIT License.
