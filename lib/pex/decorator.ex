defmodule Pex.Decorator do
  use Decorator.Define, pex: 1

  def pex(opts, body, %{args: [_conn, params]}) do
    schema = Keyword.get(opts, :schema) || raise "schema is required"
    no_errors? = Keyword.get(opts, :no_errors, false)

    quote do
      var!(params) = Pex.run(unquote(schema), unquote(params), no_errors: unquote(no_errors?))
      unquote(body)
    end
  end
end
