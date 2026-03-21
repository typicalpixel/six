defmodule Six.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/typicalpixel/six"

  def project do
    [
      app: :six,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: Six],
      test_ignore_filters: [~r/test\/fixtures\//],
      deps: deps(),
      description: "Zero-dependency Elixir coverage tool built for AI-assisted development",
      name: "Six",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      package: package()
    ]
  end

  def cli do
    [
      preferred_envs: [
        six: :test,
        "six.detail": :test,
        "six.html": :test,
        docs: :dev
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :tools]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "guides/reading-output.md",
        "guides/threshold-vs-minimum-coverage.md",
        "guides/ai-integration.md",
        "guides/github-actions.md",
        "guides/custom-formatters.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      assets: %{"assets" => "assets"},
      source_ref: "v#{@version}",
      logo: "assets/logo.png"
    ]
  end
end
