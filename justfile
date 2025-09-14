ci:
    mix format --check-formatted
    mix doctor
    mix credo
    mix dialyzer
    MIX_ENV=test mix ecto.drop
    mix test --stale

test:
    mix test
