ci:
    mix format --check-formatted
    mix credo
    mix dialyzer
    mix test --stale

test:
    mix test
