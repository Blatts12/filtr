![Filtr logo](https://raw.githubusercontent.com/Blatts12/filtr/refs/heads/main/assets/logo.png)

Parameter validation library for Elixir with Phoenix integration.

Web params arrive as strings in a map with string keys, and every handler ends up repeating the same parsing and bounds checks. Filtr takes a schema, casts each value to the type you declared, runs your validators, and hands back a map with atom keys. In Phoenix, you declare that schema with a `param` macro that reads like `attr` from Phoenix Components.

## Features

- **Phoenix integration** - Controller and LiveView support
- **Plugin system** - extend with your own types and validators
- **Three error modes** - fallback, strict and raise, overridable per field
- **Zero dependencies** - Phoenix and LiveView are optional
- **`param` macro** - declarative syntax, familiar from Phoenix Components
- **Nested schemas** - deep nesting and lists of nested schemas

## Requirements

- Elixir ~> 1.16
- Phoenix >= 1.6.0 (optional, for controller integration)
- Phoenix LiveView >= 0.20.0 (optional, for LiveView integration)

## Installation

Add `filtr` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:filtr, "~> 1.0"}
  ]
end
```

To keep the `param` macro formatted the way the macro reads, add `:filtr` to your
`.formatter.exs`:

```elixir
[import_deps: [:filtr]]
```

## Quick start

### Phoenix controller

Params are declared above the action they belong to, and the action receives them already
cast and validated.

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use Filtr.Controller, error_mode: :raise

  param :name, :string, required: true
  param :age, :integer, min: 18, max: 120
  param :email, :string, required: true, pattern: ~r/@/

  def create(conn, params) do
    json(conn, %{message: "User #{params.name} created"})
  end

  param :filters do
    param :q, :string, default: ""
    param :page, :integer, default: 1, min: 1
  end

  def search(conn, params) do
    json(conn, %{query: params.filters.q, page: params.filters.page})
  end
end
```

See `Filtr.Controller` for nested params, per-field error modes and custom error handlers.

### Phoenix LiveView

URL params are declared once for the whole LiveView, and the validated result is assigned
as `:filtr` on mount and on every navigation.

```elixir
defmodule MyAppWeb.SearchLive do
  use MyAppWeb, :live_view
  use Filtr.LiveView, error_mode: :fallback

  param :query, :string, default: ""
  param :limit, :integer, default: 10, min: 1, max: 100

  def mount(_params, _session, socket) do
    # socket.assigns.filtr.query and socket.assigns.filtr.limit
    {:ok, socket}
  end
end
```

See `Filtr.LiveView` for the hooks it attaches and the modes it accepts.

### Standalone

Outside Phoenix, write the schema as a map and call `Filtr.run/3`.

```elixir
schema = %{
  name: %{type: :string, required: true, validators: [min: 2]},
  age: %{type: :integer, validators: [min: 18, max: 120]},
  tags: %{type: {:list, :string}, default: [], validators: [max: 5]}
}

Filtr.run(schema, %{"name" => "John Doe", "age" => "25"})
# %{name: "John Doe", age: 25, tags: [], _valid?: true}
```

## Error modes

Every run happens in one of three modes. `:fallback` is the default, and replaces a bad
value with its default or `nil`. `:strict` leaves `{:error, [message]}` tuples in the
result for you to inspect, usually with `Filtr.collect_errors/1`. `:raise` raises on the
first bad value.

```elixir
config :filtr, error_mode: :strict
```

The result map always carries a `_valid?` boolean, in every mode, so you never have to
scan the fields to know whether the run was clean.

## Where to read next

The reference documentation lives with the code:

- `Filtr` - schema fields, error modes, nested schemas, custom cast and validator
  functions
- `Filtr.Controller` - the `param` macro in controllers, and custom error handlers
- `Filtr.LiveView` - params in LiveViews and how they reach the assigns
- `Filtr.DefaultPlugin` - the built-in types and every validator they support
- `Filtr.Plugin` - writing, registering and overriding plugins

Distributed under the MIT License.
