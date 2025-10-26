# Pex

Parameter validation library for Elixir with Phoenix integration.

Pex provides a flexible, plugin-based system for validating and casting parameters in Phoenix applications. It offers seamless integration with Phoenix Controllers and LiveViews using an attr-style syntax similar to Phoenix Components.

## Features

- **Phoenix Integration**
- **Plugin System**
- **Multiple Error Modes**
- **Nested Schemas**
- **Custom Validators**

## Requirements

- Elixir ~> 1.13
- Phoenix >= 1.6.0 (optional, for Controller/LiveView integration)
- Phoenix LiveView >= 0.20.0 (optional, for LiveView integration)

## Installation

Add `pex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pex, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Phoenix Controller

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Pex.Controller, error_mode: :raise

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
  use Pex.LiveView, error_mode: :raise

  param :query, :string, required: true, min: 1
  param :limit, :integer, default: 10, min: 1, max: 100

  def mount(_params, _session, socket) do
    # socket.assigns.pex contains validated params
    # socket.assigns.pex.query - validated query string
    # socket.assigns.pex.limit - validated limit (defaults to 10)
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

result = Pex.run(schema, params, error_mode: :raise)
# %{name: "John Doe", age: 25, tags: ["elixir", "phoenix"]}
```

## Error Modes

Pex supports three error handling modes:

### Fallback Mode (Default)

Returns default values or nil on validation errors:

```elixir
schema = %{age: [type: :integer, validators: [default: 18]]}
params = %{"age" => "invalid"}

Pex.run(schema, params, error_mode: :fallback)
# %{age: 18}
```

### Strict Mode

Returns error tuples for invalid values:

```elixir
schema = %{age: [type: :integer, validators: [min: 18]]}
params = %{"age" => "10"}

Pex.run(schema, params, error_mode: :strict)
# %{age: {:error, ["must be at least 18"]}}
```

### Raise Mode

Raises exceptions on validation errors:

```elixir
schema = %{name: [type: :string, validators: [required: true]]}
params = %{}

Pex.run(schema, params, error_mode: :raise)
# ** (RuntimeError) Invalid value for name: required
```

### Global Configuration

Set a default error mode in your config:

```elixir
# config/config.exs
config :pex, error_mode: :strict
```

Or specify per-module:

```elixir
use Pex.Controller, error_mode: :strict
use Pex.LiveView, error_mode: :raise
```

## Supported Types

- string
- integer
- float
- boolean
- date
- date time
- list

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

result = Pex.run(schema, params)
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

Pex.run(schema, params)
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

### Type Passthrough

For parameters that don't need validation:

```elixir
schema = %{
  metadata: [type: nil],           # Passes through any value
  raw_data: [type: :__none__]      # Passes through any value
}
```

## Plugin System

Extend Pex with custom types and validators:

```elixir
defmodule MyApp.MoneyPlugin do
  use Pex.Plugin

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
config :pex, plugins: [MyApp.MoneyPlugin]
```

Use your custom type:

```elixir
param :price, :money, min_amount: 100, max_amount: 100_000

# Accepts: "$12.99", "1,234.56", 1299 (as cents)
```

### Plugin Priority

Plugins are processed in reverse order, with later plugins taking precedence:

```elixir
config :pex, plugins: [PluginA, PluginB]

# PluginB is tried first, then PluginA, then DefaultPlugin
```

This allows you to override built-in types:

```elixir
defmodule MyApp.CustomStringPlugin do
  use Pex.Plugin

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
    Pex.DefaultPlugin.Validate.validate(value, :string, validator, opts)
  end
end
```
