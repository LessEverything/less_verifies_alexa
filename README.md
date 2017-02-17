# LessAlexa

[![Build Status](https://travis-ci.org/LessEverything/less_alexa.svg?branch=master)](https://travis-ci.org/LessEverything/less_alexa)
[![Inline docs](https://inch-ci.org/github/LessEverything/less_alexa.svg?branch=master)](https://inch-ci.org/github/LessEverything/less_alexa)

LessAlexa.ValidateRequest is a plug that validates Alexa requests. This is
a required step in certifying your Alexa skills.

## Installation

You can install `less_alexa` by adding it to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [{:less_alexa, "~> 0.1.0"}]
end
```

## Usage

Add the plug to your router like this:
```
plug LessAlexa.ValidateRequest, application_id: "your_app_id"
```

In order for the plug to work, there's an additional change you have to make.
In your `endpoint.ex`, you have to change your Parsers plug to use a custom
JSON parser that LessAlexa provides.

Just change `:json` to `:alexajson` and you should end up with something
like this:

```
plug Plug.Parsers,
  parsers: [:alexajson, :urlencoded, :multipart],
  pass: ["*/*"],
  json_decoder: Poison
```

You have to do this due to a Plug implementation detail we won't go into here.
Hopefully, we'll soon be submitting a PR to plug itself that should remove the
need for this custom adapter.

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). The docs can be found at
[https://hexdocs.pm/less_alexa](https://hexdocs.pm/less_alexa).
