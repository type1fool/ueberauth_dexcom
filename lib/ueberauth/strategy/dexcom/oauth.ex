defmodule Ueberauth.Strategy.Dexcom.OAuth do
  @moduledoc """
  OAuth2 for Dexcom.

  Add `client_id` & `client_secret` to your configuration.

  config :ueberauth, Ueberauth.Strategy.Dexcom.OAuth,
    client_id: System.get_env("DEXCOM_CLIENT_ID"),
    client_secret: System.get_env("DEXCOM_CLIENT_SECRET")
  """
  use OAuth2.Strategy

  @site if Mix.env() in [:dev, :test],
          do: "https://sandbox-api.dexcom.com",
          else: "https://api.dexcom.com"

  @defaults [
    strategy: __MODULE__,
    site: @site,
    authorize_url: "/v2/oauth2/login",
    token_url: "/v2/oauth2/token",
    redirect_url: "http://localhost/auth/callback",
    params: %{
      "grant_type" => "authorization_code"
    }
  ]

  @doc """
  Construct a client for requests to Dexcom.

  This will be set up automatically for you in `Ueberauth.Strategy.Dexcom`.
  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Dexcom.OAuth)

    opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)

    json_library = Ueberauth.json_library()

    OAuth2.Client.new(opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorization url for the request phase of Ueberauth.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> put_header("scope", "offline_access")
    |> put_header("response_type", "code")
    |> OAuth2.Client.authorize_url!(params)
  end

  def get_token!(params \\ [], opts \\ []) do
    client =
      opts
      |> client()
      |> put_header("Content-Type", "application/x-www-form-urlencoded")
      |> put_header("cache-control", "no-cache")
      |> put_param("client_secret", System.get_env("DEXCOM_CLIENT_SECRET"))
      |> OAuth2.Client.get_token!(params)

    client.token
  end

  def get(token, url, headers \\ [], opts \\ []) do
    client(token: token)
    |> put_param("client_secret", client().client_secret)
    |> OAuth2.Client.get(url, headers, opts)
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_param("client_secret", client.client_secret)
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
