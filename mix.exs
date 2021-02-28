defmodule UeberauthDexcom.MixProject do
  use Mix.Project

  @version "0.1.0"
  @url "https://github.com/type1fool/ueberauth_dexcom"

  def project do
    [
      app: :ueberauth_dexcom,
      name: "Ueberauth Dexcom",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      source_url: @url,
      homepage_url: @url,
      description: description(),
      package: package(),
      docs: docs(),
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :oauth2, :ueberauth]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ueberauth, "~> 0.6.3"},
      {:oauth2, "~> 2.0"},
      {:ex_doc, "~> 0.23", only: :dev},
      {:earmark, "~> 1.4", only: :dev}
    ]
  end

  defp docs do
    [extras: ["README.md"]]
  end

  defp description do
    "An Ueberauth strategy for Dexcom authentication."
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Owen Bickford"],
      license: ["MIT"],
      links: %{Github: @url}
    ]
  end
end
