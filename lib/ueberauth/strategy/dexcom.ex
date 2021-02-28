defmodule Ueberauth.Strategy.Dexcom do
  @moduledoc """
  Dexcom strategy for Ueberauth.
  """

  use Ueberauth.Strategy, uid_field: :id, default_scope: "offline_access"

  alias Ueberauth.Auth.{Credentials, Extra, Info}

  @doc """
  Handles initial request for Dexcom authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)
    prompt = conn.params["prompt"] || option(conn, :prompt)
    opts = [scope: scopes, prompt: prompt]

    opts =
      if conn.params["state"] do
        Keyword.put(opts, :state, conn.params["state"])
      else
        opts
      end

    opts = Keyword.put(opts, :redirect_uri, callback_url(conn))

    redirect!(conn, Ueberauth.Strategy.Dexcom.OAuth.authorize_url!(opts))
  end

  @doc false
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: callback_url(conn)]
    token = Ueberauth.Strategy.Dexcom.OAuth.get_token!([code: code], opts)

    if token.access_token == nil do
      err = token.other_params["error"]
      desc = token.other_params["error_description"]
      set_errors!(conn, [error(err, desc)])
    else
      conn
      |> store_token(token)
      |> fetch_user(token)
    end
  end

  @doc false
  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc false
  def handle_cleanup!(conn) do
    conn
    |> put_private(:dexcom_token, nil)
    |> put_private(:dexcom_user, nil)
    |> put_private(:dexcom_readings, nil)
  end

  def credentials(conn) do
    token = conn.private.dexcom_token
    scopes = split_scopes(token)

    %Credentials{
      expires: !!token.expires_at,
      expires_at: token.expires_at,
      scopes: scopes,
      refresh_token: token.refresh_token,
      token: token.access_token
    }
  end

  def info(conn) do
    # user = conn.private.dexcom_user

    %Info{}
  end

  def extra(conn) do
    %{
      dexcom_token: :token,
      dexcom_user: :user,
      dexcom_readings: :readings
    }
    |> Enum.filter(fn {original_key, _} -> Map.has_key?(conn.private, original_key) end)
    |> Enum.map(fn {original_key, mapped_key} ->
      {mapped_key, Map.fetch!(conn.private, original_key)}
    end)
    |> Map.new()
    |> (&%Extra{raw_info: &1}).()
  end

  defp store_token(conn, token) do
    put_private(conn, :dexcom_token, token)
  end

  defp fetch_user(conn, token) do
    path = "/v2/users/self/egvs"
    resp = Ueberauth.Strategy.Dexcom.OAuth.get(token, path)

    case resp do
      {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
        set_errors!(conn, [error("token", "unauthorized")])

      {:ok, %OAuth2.Response{status_code: status_code, body: user}}
      when status_code in 200..399 ->
        put_private(conn, :dexcom_user, user)

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp split_scopes(token) do
    (token.other_params["scope"] || "")
    |> String.split(" ")
  end

  defp fetch_readings(%Plug.Conn{assigns: %{ueberauth_failure: _fails}} = conn, _) do
    conn
  end

  defp fetch_readings(
         conn,
         token,
         start_date \\ "2017-06-16T15:20:00",
         end_date \\ "2017-06-16T15:30:00"
       ) do
    scopes = split_scopes(token)

    case "offline_accesss" in scopes do
      false ->
        conn

      true ->
        path = "/v2/users/self/egvs?startDate=#{start_date}&endDate=#{end_date}"

        case Ueberauth.Strategy.Dexcom.OAuth.get(token, path) do
          {:ok, %OAuth2.Response{status_code: 401, body: _body}} ->
            set_errors!(conn, [error("token", "unauthorized")])

          {:ok, %OAuth2.Response{status_code: status_code, body: readings}}
          when status_code in 200..399 ->
            put_private(conn, :dexcom_readings, readings)

          {:error, %OAuth2.Error{reason: reason}} ->
            set_errors!(conn, [error("OAuth2", reason)])
        end
    end
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
