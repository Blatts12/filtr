# Pex

A powerful Elixir library for parsing and validating query parameters in Phoenix controllers and LiveViews using declarative schemas with custom validators.

## Features

- 🔍 **Declarative Schemas** - Define parameter validation rules using simple maps
- ✅ **Type Casting** - Automatic conversion between string parameters and Elixir types
- 🛡️ **Custom Validators** - Built-in validators plus support for custom validation functions
- 🎯 **Attr-Style Integration** - Clean parameter definitions using Phoenix Component-like `param` syntax
- 🚀 **Phoenix Integration** - Seamless integration with Phoenix controllers and LiveViews
- 📊 **Comprehensive Error Handling** - Detailed error messages for validation failures
- 🛟 **Flexible Error Handling** - Multiple error modes including fallback to defaults, exceptions, or custom handlers

## Installation

Add `pex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pex, "~> 0.1.0"}
  ]
end
```

### Formatter Configuration (Optional)

To ensure proper formatting of the `param` macro calls, add Pex to your `.formatter.exs` file:

```elixir
# .formatter.exs
[import_deps: [..., :pex]] # Add :pex to the list
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
  use Pex.Controller, error_mode: :raise

  param :name, :string, required: true
  param :age, :integer, min: 18

  def create(conn, params) do
    # params.name is guaranteed to be a string
    # params.age is guaranteed to be an integer >= 18
    json(conn, %{message: "User #{params.name} created"})
  end

  param :q, :string, default: ""
  param :page, :integer, default: 1, min: 1

  def search(conn, params) do
    # params.q is a string (defaults to "")
    # params.page is an integer >= 1 (defaults to 1)
    json(conn, %{query: params.q, page: params.page})
  end
end
```

### Phoenix LiveView Integration

```elixir
defmodule MyAppWeb.ProductsLive do
  use MyAppWeb, :live_view
  use Pex.LiveView

  param :category, :string, default: "all"
  param :sort, :string, in: ["name", "price"], default: "name"
  param :page, :integer, default: 1, min: 1
  param :search, :string, default: "", min: 0, max: 100

  def handle_params(_params, _uri, socket) do
    products = load_products(socket.assigns.pex)
    {:noreply, assign(socket, products: products)}
  end

  defp load_products(params) do
    # params.category, params.sort, params.page, and params.search are validated
    MyApp.Products.list_products(params)
  end
end
```

## Parameter Definition

### Using the `param` Macro

The `param` macro provides a clean, attr-style syntax for defining parameters:

```elixir
defmodule MyAppWeb.SearchController do
  use MyAppWeb, :controller
  use Pex.Controller

  # Basic parameter with type
  param :query, :string

  # Parameter with validation options
  param :limit, :integer, min: 1, max: 100, default: 20

  # Required parameter
  param :user_id, :string, required: true

  # Parameter with enum validation
  param :status, :string, in: ["active", "inactive"], default: "active"

  # List parameter
  param :tags, {:list, :string}, default: []

  # Nested schema
  param :user, %{id: [type: :string]}

  # List of schema
  param :users, [%{id: [type: :string]}]

  def index(conn, params) do
    # All params are validated and accessible as params.query, params.limit, etc.
    render(conn, "index.html", params: params)
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
- `{:list, type}` - List of specified type or schema
- `%{key: [type: :string]}` - Nested schema

### Schema Options

Each parameter can include these options:

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
defmodule MyAppWeb.ExampleController do
  use MyAppWeb, :controller
  use Pex.Controller

  param :name, :string, default: "Anonymous"
  param :timestamp, :datetime, default: &DateTime.utc_now/0
  param :computed, :string, default: fn -> generate_id() end

  def show(conn, params) do
    # All defaults are applied if parameters are missing
    render(conn, "show.html", params: params)
  end
end
```

### Custom Validation

You can provide custom validation functions:

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Pex.Controller

  param :email, :string, validate: fn email ->
    if String.contains?(email, "@") do
      :ok
    else
      {:error, "must be a valid email"}
    end
  end

  def create(conn, params) do
    render(conn, "create.html", email: params.email)
  end
end
```

## Error Handling

### Error Mode Options

Use the `:error_mode` option to control how validation errors are handled:

#### Fallback Mode (Recommended and Default)

By default, gracefully fallbacks to defaults or `nil` if default is not provided:

```elixir
defmodule MyAppWeb.SearchController do
  use MyAppWeb, :controller
  use Pex.Controller

  param :q, :string, default: ""
  param :page, :integer, default: 1, min: 1

  def index(conn, params) do
    # params will always have valid values, falling back to defaults
    render(conn, "index.html", query: params.q, page: params.page)
  end
end
```

#### Strict Mode

Use `error_mode: :raise` to return validation errors as error tuples in the validated params:

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Pex.Controller, error_mode: :raise

  param :name, :string, required: true

  def create(conn, params) do
    case params.name do
      {:error, _errors} ->
        put_status(conn, 400) |> json(%{error: "Name is required"})

      name when is_binary(name) ->
        json(conn, %{message: "Hello #{name}"})
    end
  end
end
```

#### Raise Mode

Use `error_mode: :raise` to raise exceptions on validation failures:

```elixir
defmodule MyAppWeb.AdminController do
  use MyAppWeb, :controller
  use Pex.Controller, error_mode: :raise

  param :admin_key, :string, required: true

  def secret_action(conn, params) do
    # Will raise ArgumentError if admin_key is missing
    render(conn, "secret.html", key: params.admin_key)
  end
end
```

#### Custom Function

Use `error_mode: function` to provide custom error handling:

```elixir
defmodule MyAppWeb.ApiController do
  use MyAppWeb, :controller

  def halt_with_errors(_key, _errors), do: :bad
  # def halt_with_errors(key, errors, params), do: :bad

  use Pex.Controller, error_mode: &__MODULE__.halt_with_errors/2
  # use Pex.Controller, error_mode: &__MODULE__.halt_with_errors/3

  param :api_key, :string, required: true

  def data(conn, params) do
    case params do
      {:error, :validation_failed} ->
        put_status(conn, 400) |> json(%{error: "Validation failed"})

      _ ->
        json(conn, %{data: "secret data"})
    end
  end
end
```

## Testing

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover
```
