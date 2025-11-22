ci:
    mix format --check-formatted
    mix credo
    mix dialyzer
    mix test --stale

test:
    mix test

pub:
    mix hex.publish

pubdocs:
    mix hex.publish docs

docs:
    mix docs --open
