defmodule LessVerifiesAlexa.Plug do
  @moduledoc """
  `LessVerifiesAlexa.Plug` is a plug that validates requests that
  Amazon's Alexa service sends.

  Add the plug to your router like this:
  ```
  plug LessVerifiesAlexa.Plug, application_id: "your_app_id"
  ```

  In order for the plug to work, there's an additional change you have to make.
  In your `endpoint.ex`, you have to change your Parsers plug to use a custom
  JSON parser that this plug provides.

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
  """
  import Plug.Conn

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t, keyword()) :: Plug.Conn.t
  def call(conn, opts) do
    conn
    |> check_signature_url
    |> check_application_id(opts[:application_id])
    |> check_certificate_validity
    |> check_request_timestamp
  end

  defp check_signature_url(conn) do
    [signature_certchain_url] = get_req_header(conn, "signaturecertchainurl")

    case is_alexa_url?(signature_certchain_url) do
      true -> conn
      false -> halt(conn)
    end
  end

  defp check_application_id(_conn, nil) do
    raise ArgumentError, "ValidateRequest expects an :application_id option"
  end

  defp check_application_id(conn, app_id) do
    # TODO: Error checking
    received_id = conn.body_params["session"]["application"]["applicationId"]
    case received_id == app_id do
      true -> conn
      false -> halt(conn)
    end
  end

  defp check_certificate_validity(conn) do
    [signature] = get_req_header(conn, "signature")
    [cert_url] = get_req_header(conn, "signaturecertchainurl")
    raw_body = conn.private[:raw_body]
    {:ok, cert} = LessVerifiesAlexa.Certificate.fetch(cert_url)

    case LessVerifiesAlexa.Certificate.valid?(signature, cert, raw_body) do
      :ok -> conn
      _ -> halt(conn)
    end
  end

  defp is_alexa_url?(chain_url) do
    case Regex.run(~r/^https:\/\/s3.amazonaws.com(:443)?(\/echo\.api\/)/i, chain_url) do
      [_, "", "/echo.api/"] -> true
      [_, ":443", "/echo.api/"] -> true
      _ -> false
    end
  end

  defp check_request_timestamp(conn) do
    {:ok, request_date_time, _offset} =
      DateTime.from_iso8601(conn.params["request"]["timestamp"])

    request_unix_time = DateTime.to_unix(request_date_time)

    case requested_within_150_seconds(request_unix_time) do
      true -> conn
      false -> halt(conn)
    end
  end

  defp requested_within_150_seconds(request_unix_time) do
    now_unix_time = DateTime.to_unix(DateTime.utc_now)

    abs(now_unix_time - request_unix_time) <= 150
  end
end
