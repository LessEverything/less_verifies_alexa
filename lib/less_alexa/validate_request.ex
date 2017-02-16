defmodule LessAlexa.ValidateRequest do
  import Plug.Conn

  def init(opts), do: opts

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
    cert = LessAlexa.Certificate.fetch(cert_url)

    case LessAlexa.Certificate.valid?(signature, cert, raw_body) do
      true -> conn
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
