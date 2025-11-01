# Used by "mix format"
locals_without_parens = [param: 2, param: 3]

[
  plugins: [Styler],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
