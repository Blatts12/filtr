defmodule Filtr do
  @moduledoc """
  Parameter validation and casting for Elixir, with Phoenix integration.

  Web params arrive as strings in a map with string keys, and every handler ends up
  repeating the same parsing and bounds checks. Filtr takes a schema, casts each value
  to the type you declared, runs your validators, and hands back a map with atom keys.

  This module is the entry point for standalone use. If you are in a Phoenix app, look
  at `Filtr.Controller` and `Filtr.LiveView` instead. They give you a `param` macro that
  builds the schema at compile time.

  ## Schema shape

  A schema is a map of keys to key schemas. Each key schema is itself a map, with `:type`
  as the only required field.

      schema = %{
        name: %{type: :string, required: true, validators: [min: 2]},
        age: %{type: :integer, validators: [min: 18, max: 120]},
        tags: %{type: {:list, :string}, default: [], validators: [max: 5]}
      }

      Filtr.run(schema, %{"name" => "John Doe", "age" => "25"})
      # %{name: "John Doe", age: 25, tags: [], _valid?: true}

  Let's break down the fields of a key schema:

  - `:type` - a type atom handled by a plugin (see `Filtr.DefaultPlugin`), a `{:list, type}`
    tuple, a nested schema map, `nil` or `:__none__` to pass the value through untouched,
    or a function of arity 1, 2 or 3 to cast the value yourself.
  - `:required` - when `true`, a missing or empty value is an error. Required is checked
    before `:default`, so in `:strict` and `:raise` mode a required key with a default
    still fails when the param is absent.
  - `:default` - the value used when the key is missing, or when it fails in `:fallback`
    mode. A zero-arity or one-arity function is called for you, which is how you get
    dynamic defaults like timestamps.
  - `:validators` - a keyword list of rules the plugin for that type understands, plus
    `custom: fun` for your own check.
  - `:error_mode` - overrides the run-wide mode for this one key.

  Nesting works by putting a schema map in `:type`, and lists of nested maps by putting
  one in a `{:list, schema}` tuple.

  ## Error modes

  Every run happens in one of three modes, passed as `error_mode:` to `run/3`:

  - `:fallback` (the default) replaces a bad value with its `:default`, or `nil` when
    there is none. Nothing blows up, so you get a usable map out of hostile input.
  - `:strict` leaves `{:error, [message]}` tuples in the result map for you to inspect.
  - `:raise` raises a `RuntimeError` on the first bad value.

  Set the app-wide default in config, and note that Filtr reads it at compile time:

      config :filtr, error_mode: :strict

  Pick the mode per use case. `:fallback` is forgiving but silent, so a typo in a filter
  param looks the same as no param at all. `:strict` is the honest choice for forms and
  APIs, at the cost of checking `_valid?` yourself.

  ## Reading the result

  The result map always carries a `_valid?` boolean, in every mode, so you never have to
  scan the fields to know whether the run was clean. In `:strict` mode, `collect_errors/1`
  turns the scattered error tuples into one nested map of messages.

      result = Filtr.run(schema, params, error_mode: :strict)

      if result._valid? do
        save(result)
      else
        render_errors(Filtr.collect_errors(result))
      end

  ## Nested schemas and lists

  Put a schema map in `:type` to validate a nested map of params, and wrap one in a
  `{:list, schema}` tuple for a list of them. Nesting goes as deep as you need.

      schema = %{
        user: %{
          type: %{
            name: %{type: :string, required: true},
            address: %{type: %{country: %{type: :string, default: "US"}}}
          }
        },
        items: %{
          type:
            {:list,
             %{
               name: %{type: :string, required: true},
               quantity: %{type: :integer, default: 1, validators: [min: 1]}
             }}
        }
      }

      Filtr.run(schema, %{
        "user" => %{"name" => "John", "address" => %{}},
        "items" => [%{"name" => "Rope", "quantity" => "2"}]
      })
      # %{
      #   user: %{name: "John", address: %{country: "US"}},
      #   items: [%{name: "Rope", quantity: 2}],
      #   _valid?: true
      # }

  Phoenix parses `items[0][name]=Rope` into a map keyed by index rather than a list, and
  Filtr turns those back into a list for you. The keys are sorted numerically, so item 10
  lands after item 2 the way you would expect. Keys that are not numbers keep plain key
  order, which is the sensible fallback but not an order worth relying on.

  ## Casting with your own function

  When a type belongs to one schema only, skip the plugin and put a function in `:type`.
  Filtr picks the clause by arity, passing the value, then the key schema and the run
  context as you ask for more arguments.

      slugify = fn value, _ctx ->
        case String.trim(value) do
          "" -> {:error, "cannot be blank"}
          trimmed -> {:ok, String.downcase(trimmed)}
        end
      end

      Filtr.run(%{slug: %{type: slugify}}, %{"slug" => " My Post "})
      # %{slug: "my post", _valid?: true}

  The arities are `value`, then `(value, context)`, then `(value, key_schema, context)`.
  Return `{:ok, value}` or `{:error, message}`, and note that a bare value is accepted too
  and treated as success.

  ## Custom validators

  The `custom:` validator takes a function, again dispatched by arity: `value`,
  `(value, type)`, or `(value, type, context)`.

      email? = fn value -> String.contains?(value, "@") end

      %{email: %{type: :string, validators: [custom: email?]}}

  Passing counts as `:ok`, `true` or `{:ok, _}`. Failing counts as `:error`, `false` or
  `{:error, message}`, and the first two produce the message "invalid value".

  ## Passing values through

  Set `:type` to `nil` or `:__none__` for a param you want kept as is, with no casting and
  no validation.

      %{metadata: %{type: nil}}

  A word of caution about `:__none__`. It is also the internal marker for a missing param,
  so avoid returning it as a real value from your own casts.
  """

  @spec run(schema :: map(), params :: map()) :: map()
  @spec run(schema :: map(), params :: map(), run_opts :: keyword()) :: map()
  def run(schema, params, run_opts \\ []) do
    Filtr.Processor.run(schema, params, run_opts)
  end

  @doc """
  Collects all errors from a Filtr result map into a structured error map.

  This function is primarily useful when using `:strict` error mode, where errors
  are returned as `{:error, [...]}` tuples in the result map rather than being
  replaced with default values (`:fallback`) or raising exceptions (`:raise`).

  This function traverses the result map returned by `Filtr.run/2` or `Filtr.run/3` and extracts
  all error tuples, organizing them into a hierarchical structure that mirrors the
  original schema structure.
  ## Examples

      iex> result = %{name: {:error, "required"}, age: 25}
      iex> Filtr.collect_errors(result)
      %{name: ["required"]}


      iex> result = %{name: "John", age: 25}
      iex> Filtr.collect_errors(result)
      nil

      iex> result = %{
      ...>   user: %{
      ...>     name: {:error, "required"},
      ...>     age: 25
      ...>   }
      ...> }
      iex> Filtr.collect_errors(result)
      %{user: %{name: ["required"]}}

      iex> result = %{tags: ["valid", {:error, "too short"}, "another"]}
      iex> Filtr.collect_errors(result)
      %{tags: %{1 => ["too short"]}}

      iex> result = %{
      ...>   users: [
      ...>     %{id: 1, name: "john"},
      ...>     %{id: 2, name: {:error, "required"}}
      ...>   ]
      ...> }
      iex> Filtr.collect_errors(result)
      %{users: %{1 => %{name: ["required"]}}}

  """
  @spec collect_errors(filtr_result :: map()) :: map() | nil
  defdelegate collect_errors(filtr_result), to: Filtr.Errors, as: :collect
end
