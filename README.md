# Pex

A powerful Elixir library for parsing and validating query parameters in Phoenix controllers and LiveViews using declarative schemas with custom validators.

## Features

- 🔍 **Declarative Schemas** - Define parameter validation rules using simple maps
- ✅ **Type Casting** - Automatic conversion between string parameters and Elixir types
- 🛡️ **Custom Validators** - Built-in validators plus support for custom validation functions
- 🎯 **Decorator Integration** - Clean controller annotations using the decorator package
- 🚀 **Phoenix Integration** - Seamless integration with Phoenix controllers and LiveViews
- 📊 **Comprehensive Error Handling** - Detailed error messages for validation failures

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
# Define a schema
schema = %{
  page: [type: :integer, default: 1],
  limit: [type: :integer, default: 10, validator: &Pex.Validators.range(&1, 1, 100)],
  search: [type: :string, optional: true],
  active: [type: :boolean, default: true]
}

# Parse query parameters
case Pex.parse(%{"page" => "2", "search" => "elixir"}, schema) do
  {:ok, params} ->
    # params = %{page: 2, limit: 10, search: "elixir", active: true}
    IO.inspect(params)
  
  {:error, errors} ->
    # Handle validation errors
    IO.inspect(errors)
end
```

### Phoenix Controller Integration

```elixir
defmodule MyAppWeb.UserController do
  use Phoenix.Controller
  use Pex.Controller

  @pex_schema %{
    page: [type: :integer, default: 1, validator: &Pex.Validators.positive/1],
    limit: [type: :integer, default: 10, validator: &Pex.Validators.range(&1, 1, 100)],
    search: [type: :string, optional: true],
    sort: [type: :string, default: "name", validator: &Pex.Validators.one_of(&1, ["name", "email", "created_at"])]
  }

  @decorate pex_params(@pex_schema)
  def index(conn, _params) do
    # Validated params available as conn.assigns.pex_params
    %{page: page, limit: limit, search: search, sort: sort} = conn.assigns.pex_params
    
    users = MyApp.Users.list_users(page: page, limit: limit, search: search, sort: sort)
    render(conn, "index.html", users: users)
  end
end
```

### Phoenix LiveView Integration

```elixir
defmodule MyAppWeb.UserLive.Index do
  use Phoenix.LiveView
  import Pex.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    schema = %{
      page: [type: :integer, default: 1],
      search: [type: :string, optional: true]
    }

    case parse_params(params, schema) do
      {:ok, validated_params} ->
        socket = 
          socket
          |> assign(:params, validated_params)
          |> load_users()
        
        {:noreply, socket}
      
      {:error, _errors} ->
        {:noreply, put_flash(socket, :error, "Invalid parameters")}
    end
  end

  defp load_users(socket) do
    %{page: page, search: search} = socket.assigns.params
    users = MyApp.Users.list_users(page: page, search: search)
    assign(socket, :users, users)
  end
end
```

## Schema Definition

Schemas are defined as maps where keys are parameter names and values are keyword lists of options:

```elixir
schema = %{
  parameter_name: [
    type: :string | :integer | :float | :boolean | :list,
    default: any(),           # Default value if parameter is missing
    optional: boolean(),      # Whether parameter is optional (default: false)
    validator: function()     # Custom validator function
  ]
}
```

### Supported Types

- `:string` - String values (default)
- `:integer` - Integer values, parsed from strings
- `:float` - Float values, parsed from strings  
- `:boolean` - Boolean values, accepts "true"/"false", "1"/"0", "yes"/"no"
- `:list` - List values, parsed from comma-separated strings

### Built-in Validators

Pex includes several built-in validators:

```elixir
# Positive numbers
validator: &Pex.Validators.positive/1

# Range validation
validator: &Pex.Validators.range(&1, 1, 100)

# String length validation
validator: &Pex.Validators.min_length(&1, 3)
validator: &Pex.Validators.max_length(&1, 50)

# Allowed values
validator: &Pex.Validators.one_of(&1, ["red", "green", "blue"])

# Format validation with regex
validator: &Pex.Validators.format(&1, ~r/^[a-z]+$/)

# List validation
validator: &Pex.Validators.not_empty/1
validator: &Pex.Validators.length(&1, 3)
```

### Custom Validators

Create custom validators that return `{:ok, value}` or `{:error, message}`:

```elixir
def validate_email(email) do
  if String.contains?(email, "@") do
    {:ok, email}
  else
    {:error, "must be a valid email address"}
  end
end

schema = %{
  email: [type: :string, validator: &validate_email/1]
}
```

## API Reference

### Core Functions

- `Pex.parse(params, schema)` - Parse and validate parameters according to schema

### Controller Helpers

- `Pex.Controller.parse_params(conn, schema)` - Parse parameters from connection
- `Pex.Controller.assign_parsed_params(conn, schema)` - Parse and assign to connection
- `Pex.Controller.get_parsed_params(conn)` - Get validated parameters from assigns
- `Pex.Controller.get_param_errors(conn)` - Get validation errors from assigns

### LiveView Helpers

- `Pex.LiveView.parse_params(params, schema)` - Parse parameters in LiveView
- `Pex.LiveView.parse_live_params(socket, schema)` - Parse from LiveView socket
- `Pex.LiveView.assign_parsed_params(socket, schema, key)` - Parse and assign to socket
- `Pex.LiveView.push_parsed_params(socket, params)` - Update URL with validated params

## Error Handling

Validation errors are returned as maps with parameter names as keys and error messages as values:

```elixir
{:error, %{
  page: "invalid integer",
  limit: "must be between 1 and 100",
  email: "must be a valid email address"
}}
```

When using decorators, validation failures automatically return a 400 Bad Request response with JSON error details.

## Documentation

Full documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc):

```bash
mix docs
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

