![Filtr logo](https://raw.githubusercontent.com/Blatts12/filtr/refs/heads/main/assets/logo.png)

Parameter validation library for Elixir with Phoenix integration.

Filtr provides a flexible, plugin-based system for validating and casting parameters in Phoenix applications. It offers seamless integration with Phoenix Controllers and LiveViews using an attr-style syntax similar to Phoenix Components.

## Features

- **Phoenix Integration** - Seamless Controller and LiveView support
- **Plugin System** - Extend with custom types and validators
- **Multiple Error Modes** - Fallback, strict, and raise modes with per-field overrides
- **Zero Dependencies** - Lightweight core library
- **attr-like `param` macro** - Familiar, declarative syntax just like for Phoenix Components
- **Nested Schemas** - Deep nesting with `param ... do...end` macro syntax

## Requirements

- Elixir ~> 1.16
- Phoenix >= 1.6.0 (optional, for Controller/LiveView integration)
- Phoenix LiveView >= 0.20.0 (optional, for LiveView integration)

## Installation

Add `filtr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:filtr, "~> 0.4.0"}
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

  # Nested parameters
  param :filters do
    param :q, :string, default: ""
    param :page, :integer, default: 1, min: 1
    param :category, :string, in: ["books", "movies", "music"], default: "books"
  end

  def search(conn, params) do
    json(conn, %{query: params.filters.q, page: params.filters.page})
  end

  # List of nested schema
  param :items, :list do
    param :name, :string, required: true
    param :quantity, :integer, min: 1, default: 1
  end

  def order(conn, params) do
    # params.items is a list
    json(conn, %{items: params.items})
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

  # Nested parameters for better organization
  param :filters do
    param :category, :string, default: "all"
    param :sort, :string, in: ["name", "date"], default: "name"
  end

  # List of nested schemas
  param :tags, :list do
    param :label, :string, required: true
    param :color, :string, in: ["red", "blue", "green"], default: "blue"
  end

  def mount(_params, _session, socket) do
    # socket.assigns.filtr contains validated params
    # socket.assigns.filtr.query - validated query string
    # socket.assigns.filtr.limit - validated limit (defaults to 10)
    # socket.assigns.filtr.filters.category - validated category
    # socket.assigns.filtr.filters.sort - validated sort
    # socket.assigns.filtr.tags - validated list of tag objects
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
      conn
      |> put_status(:bad_request)
      |> json(%{errors: collect_errors(params)})
    end
  end
end
```

## Advanced Features

### Nested Schemas

Filtr supports nested schemas with two syntaxes:

#### Macro Syntax (Controllers & LiveViews)

Use the `param do...end` syntax for clean, declarative nested schemas:

```elixir
defmodule MyAppWeb.UserController do
  use Filtr.Controller

  param :user do
    param :name, :string, required: true
    param :email, :string, required: true, pattern: ~r/@/
    param :age, :integer, min: 18
  end

  param :settings do
    param :theme, :string, in: ["light", "dark"], default: "light"
    param :notifications, :boolean, default: true
  end

  def create(conn, params) do
    # params.user.name
    # params.user.email
    # params.settings.theme
    json(conn, %{message: "User #{params.user.name} created"})
  end
end
```

**Deep nesting** is fully supported:

```elixir
param :company do
  param :name, :string, required: true

  param :headquarters do
    param :country, :string, default: "US"

    param :contact do
      param :email, :string, required: true
      param :phone, :string, default: ""
    end
  end
end

# Access: params.company.headquarters.contact.email
```

#### Map Syntax (Standalone)

For standalone usage, use the map syntax:

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

Filtr supports lists containing nested schema, allowing you to validate arrays of complex objects.

#### Macro Syntax (Controllers & LiveViews)

Use the `param :field, :list do...end` syntax for clean, declarative list schemas:

```elixir
defmodule MyAppWeb.OrderController do
  use Filtr.Controller

  # List of items with nested validation
  param :items, :list do
    param :name, :string, required: true
    param :quantity, :integer, min: 1, default: 1
    param :price, :float, min: 0
  end

  def create(conn, params) do
    # params.items is a list of validated item objects
    # Each item has validated name, quantity, and price fields
    total = Enum.reduce(params.items, 0, fn item, acc ->
      acc + (item.quantity * item.price)
    end)

    json(conn, %{total: total})
  end
end
```

**LiveView with URL Parameters:**

```elixir
defmodule MyAppWeb.UserLive do
  use Filtr.LiveView

  param :users, :list do
    param :name, :string, required: true
    param :age, :integer, min: 18
  end

  def mount(_params, _session, socket) do
    # socket.assigns.filtr.users is a validated list
    {:ok, socket}
  end
end

# URL format: /users?users[0][name]=John&users[0][age]=25&users[1][name]=Jane&users[1][age]=30
# Converts to: [%{name: "John", age: 25}, %{name: "Jane", age: 30}]
```

#### Map Syntax (Standalone)

For standalone usage, use the map syntax with `{:list, schema}`:

```elixir
schema = %{
  items: [
    type: {
      :list,
      %{
        name: [type: :string, validators: [required: true]],
        quantity: [type: :integer, validators: [min: 1]]
      }
    }
  ]
}

params = %{
  "items" => [
    %{"name" => "Product A", "quantity" => "5"},
    %{"name" => "Product B", "quantity" => "3"}
  ]
}

result = Filtr.run(schema, params)
# %{items: [
#   %{name: "Product A", quantity: 5},
#   %{name: "Product B", quantity: 3}
# ]}
```

#### Indexed Map Support

Phoenix parses URL array parameters as indexed maps. Filtr automatically converts these to lists:

```elixir
# Phoenix converts: users[0][name]=John&users[1][name]=Jane
# Into: %{"users" => %{"0" => %{"name" => "John"}, "1" => %{"name" => "Jane"}}}

# Filtr automatically converts to:
# %{users: [%{name: "John"}, %{name: "Jane"}]}
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

### Custom Error Handlers (Controllers)

Instead of using built-in error modes, you can provide a custom error handler function that receives the connection and validated params when validation fails. This gives you full control over the error response.

#### Function Capture

```elixir
defmodule MyAppWeb.ErrorHandler do
  def handle_validation_error(conn, params) do
    conn
    |> Plug.Conn.put_status(:bad_request)
    |> Phoenix.Controller.json(%{errors: Filtr.collect_errors(params)})
    |> Plug.Conn.halt()
  end
end

defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Filtr.Controller, error_mode: &MyAppWeb.ErrorHandler.handle_validation_error/2

  param :name, :string, required: true
  param :email, :string, required: true, pattern: ~r/@/

  def create(conn, params) do
    # Only called when validation passes
    json(conn, %{message: "User #{params.name} created"})
  end
end
```

#### MFA Tuple

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Filtr.Controller, error_mode: {MyAppWeb.ErrorHandler, :handle_validation_error, 2}

  param :name, :string, required: true

  def create(conn, params) do
    json(conn, %{user: params.name})
  end
end
```

#### Anonymous Function

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Filtr.Controller,
    error_mode: fn conn, params ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: collect_errors(params)})
      |> halt()
    end

  param :name, :string, required: true

  def create(conn, params) do
    json(conn, %{user: params.name})
  end
end
```

**Handler function signature:**

The error handler function must have arity 2 and receives:

- `conn` - The Plug connection
- `params` - The validated params map (with `_valid?: false` and error tuples for invalid fields)

**When is the handler called?**

The custom error handler is only called when `params._valid?` is `false`. If all parameters pass validation, the original controller function is called with the validated params.

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

Filtr uses this information to build a type-to-plugin mapping at runtime (cached in `:persistent_term` for performance). When processing a parameter, Filtr looks up which plugin handles that type. The mapping is built on first use and cached for subsequent requests, giving near compile-time performance.

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

When you use `Filtr.Plugin`, a catch-all clause is automatically added to your plugin at compile time using `@before_compile`. This means you **don't need to manually add catch-all clauses** - if your function pattern doesn't match, Filtr automatically returns `:not_handled`.

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

The validator parameter is a tuple like `{:min, 100}` or `{:in, ["USD", "EUR"]}`. Your plugin only needs to implement validators it supports - if a validator isn't recognized, the automatic catch-all clause returns `:not_handled`.

### Plugin Priority

Plugins are processed in reverse order, with later plugins completely overriding earlier ones for the same type:

```elixir
config :filtr, plugins: [PluginA, PluginB]

# For any type that PluginB declares in types/0, PluginB handles it
# For types only declared by PluginA, PluginA handles them
# For types only in DefaultPlugin, DefaultPlugin handles them
```

This allows you to override built-in types:

```elixir
defmodule MyApp.CustomStringPlugin do
  use Filtr.Plugin

  @impl true
  def types, do: [:string]

  @impl true
  def cast(value, :string, _opts) do
    # Custom string handling - this completely replaces DefaultPlugin for :string
    {:ok, String.trim(value)}
  end

  @impl true
  def validate(value, :string, validator, opts) do
    # You can delegate to DefaultPlugin for validators you don't want to reimplement
    Filtr.DefaultPlugin.validate(value, :string, validator, opts)
  end
end
```

When multiple plugins declare the same type, the last plugin in the list takes full ownership of that type. If you want to reuse logic from `DefaultPlugin`, you can explicitly delegate to it as shown above.

### Default Plugin

Filtr includes a built-in `DefaultPlugin` that provides support for common data types. This plugin is always processed first, so custom plugins can override its behavior for any type.

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
- [ ] Even More Tests
- [ ] Benchmarks
- [ ] CI/CD
- [ ] Improve `README.md`
- [ ] Introduce `AGENTS.md` or `CLAUDE.md` file
- [ ] Debug logging
- [x] `_valid?` field for strict mode to know if params are valid
- [x] Move on from `try catch` to different approach for plugin chaining
- [x] Extract errors function for strict mode
- [x] Custom error modes for controllers (return 400 error on fail in controllers?)
- [ ] Custom error modes for liveviews (redirect on fail?)
- [x] Macro for nested schemas

Distributed under the MIT License.
