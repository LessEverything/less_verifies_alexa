defmodule LessVerifiesAlexa.Mixfile do
  use Mix.Project

  def project do
    [app: :less_verifies_alexa,
     description: "A plug that validates requests from Amazon's Alexa service.",
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     docs: [main: "Plug.VerifyAlexa"],
     package: [
       name: :less_verifies_alexa,
       maintainers: ["Steven Bristol", "Eugen Minciu"],
       files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
       licenses: ["Apache 2.0"],
       links: %{"GitHub" => "https://github.com/LessEverything/less_verifies_alexa",
              "Docs" => "http://hex.pm/less_verifies_alexa"}
     ]
    ]
  end

  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:plug, ">= 1.3.0"},
      {:certifi, ">= 0.0.0"},
      {:httpotion, "~> 3.0"},
      {:credo, "~> 0.6", only: [:dev], runtime: false},
      {:dialyxir, "~> 0.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.12", only: :docs},
      {:inch_ex, ">= 0.0.0", only: :docs}
    ]
  end
end
