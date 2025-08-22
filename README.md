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

## Quick Start

### Basic Usage

```elixir
# Define a schema for your parameters
schema = %{
  name: [type: :string, required: true],
  age: [type: :integer, min: 0, max: 120],
  email: [type: :string, pattern: ~r/@/],
  tags: [type: {:list, :string}]
}

# Parse and validate parameters
params = %{"name" => "John", "age" => "25", "email" => "john@example.com", "tags" => "elixir,phoenix"}
result = Pex.run(schema, params)
# => %{name: "John", age: 25, email: "john@example.com", tags: ["elixir", "phoenix"]}
```

### Phoenix Controller Integration

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Pex.Decorator

  @decorate pex(schema: %{
    name: [type: :string, required: true],
    age: [type: :integer, min: 18]
  })
  def create(conn, params) do
    # params is now validated and cast according to schema
    IO.inspect(params) # %{name: "John", age: 25}
    # ... rest of controller action
  end
end
```

### Phoenix LiveView Integration

```elixir
defmodule MyAppWeb.UserLive do
  use MyAppWeb, :live_view
  use Pex.LiveView, schema: %{
    search: [type: :string, default: ""],
    page: [type: :integer, default: 1, min: 1]
  }

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    # Access validated params with socket.assigns.pex
    search = socket.assigns.pex.search
    page = socket.assigns.pex.page
    {:noreply, socket}
  end
end
```

## Schema Definition

### Basic Types

Pex supports the following built-in types:

- `:string` - String values
- `:integer` - Integer numbers
- `:float` - Floating point numbers
- `:boolean` - Boolean values (true/false/"true"/"false"/"1"/"0")
- `:date` - Date values (ISO8601 format)
- `:datetime` - DateTime values (ISO8601 format)
- `:list` - List of strings
- `{:list, type}` - List of specified type

### Schema Options

Each field in your schema can include these options:

#### Common Options

- `type` - The expected type (required)
- `required` - Whether the field is required (default: false)
- `default` - Default value or function to generate default
- `validate` - Custom validation function

#### String Options

- `min` - Minimum string length
- `max` - Maximum string length
- `pattern` - Regex pattern to match
- `starts_with` - String must start with this prefix
- `ends_with` - String must end with this suffix
- `in` - Value must be in this list

#### Numeric Options (Integer/Float)

- `min` - Minimum value
- `max` - Maximum value
- `in` - Value must be in this list

#### Date/DateTime Options

- `min` - Minimum date/datetime
- `max` - Maximum date/datetime
- `in` - Value must be in this list

#### List Options

- `min` - Minimum list length
- `max` - Maximum list length

### Default Values

Default values can be static values or functions:

```elixir
schema = %{
  name: [type: :string, default: "Anonymous"],
  timestamp: [type: :datetime, default: &DateTime.utc_now/0],
  computed: [type: :string, default: fn -> generate_id() end],
  contextual: [type: :string, default: fn key, params ->
    "#{key}_#{params["user_id"]}"
  end]
}
```

### Custom Validation

You can provide custom validation functions:

```elixir
schema = %{
  email: [
    type: :string,
    validate: fn email ->
      if String.contains?(email, "@") do
        :ok
      else
        {:error, "must be a valid email"}
      end
    end
  ]
}
```

### Nested Schemas

Pex supports nested parameter structures:

```elixir
schema = %{
  user: %{
    name: [type: :string, required: true],
    age: [type: :integer, min: 0]
  },
  settings: %{
    theme: [type: :string, in: ["light", "dark"], default: "light"],
    notifications: [type: :boolean, default: true]
  }
}

params = %{
  "user" => %{"name" => "John", "age" => "25"},
  "settings" => %{"theme" => "dark"}
}

result = Pex.run(schema, params)
# => %{
#   user: %{name: "John", age: 25},
#   settings: %{theme: "dark", notifications: true}
# }
```

## Error Handling

### Strict Mode (Default)

By default, Pex returns error tuples:

```elixir
schema = %{name: [type: :string, required: true]}
params = %{}

Pex.run(schema, params)
# Returns: %{name: {:error, ["required"]}}
```

### No-Error Mode

Use `:no_errors` option for graceful fallback to defaults:

```elixir
schema = %{
  name: [type: :string, required: true, default: "Anonymous"],
  age: [type: :integer, default: 0]
}
params = %{"age" => "invalid"}

result = Pex.run(schema, params, no_errors: true)
# => %{name: "Anonymous", age: 0}
```

## Advanced Features

### Custom Type Casting

You can provide custom casting functions:

```elixir
schema = %{
  custom_field: [
    type: :string,
    cast: fn value ->
      {:ok, String.upcase(value)}
    end
  ]
}
```

### Phoenix Controller with No-Error Mode

```elixir
defmodule MyAppWeb.SearchController do
  use MyAppWeb, :controller
  use Pex.Decorator

  @decorate pex(
    schema: %{
      q: [type: :string, default: ""],
      page: [type: :integer, default: 1, min: 1]
    },
    no_errors: true
  )

  def index(conn, params) do
    # params will always have valid values, falling back to defaults
    render(conn, "index.html", query: params.q, page: params.page)
  end
end
```

### LiveView with No-Error Mode

For graceful parameter handling in LiveViews:

```elixir
defmodule MyAppWeb.SearchLive do
  use MyAppWeb, :live_view
  use Pex.LiveView,
    schema: %{
      search: [type: :string, default: ""],
      page: [type: :integer, default: 1, min: 1],
      filters: [type: {:list, :string}, default: []]
    },
    no_errors: true

  def handle_params(_params, _uri, socket) do
    # All parameters are guaranteed to have valid values
    search_results = perform_search(socket.assigns.pex)
    {:noreply, assign(socket, results: search_results)}
  end

  defp perform_search(params) do
    # params.search, params.page, and params.filters are all validated
    MyApp.Search.query(params)
  end
end
```

## Testing

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/pex_test.exs
```
