defmodule LessVerifiesAlexa.Certificate do
  @moduledoc """
  This module is used as a part of the certificate validation process.
  It's responsible for fetching Amazon PEMs and using them to
  validate any incoming requests.
  """
  require Record

  @pubkey_schema Record.extract_all(from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  @subject_altname_id {2, 5, 29, 17}

  @spec valid?(String.t, String.t, String.t) :: :ok | {:error, atom()}
  def valid?(signature, pem, raw_body) do
    certs = pem
      |> :public_key.pem_decode()
      |> Enum.map(&get_cert_value/1)
    decoded_certs = Enum.map(certs, &decode_cert/1)

    dates_valid = check_cert_dates(decoded_certs)
    subject_valid = check_san(decoded_certs)
    cert_path_valid = check_cert_path(certs)
    signature_valid = confirm_payload_signature(
      hd(decoded_certs), signature, raw_body
    )

    case {dates_valid, subject_valid, cert_path_valid, signature_valid} do
      {false, _, _, _} -> {:error, :invalid_dates}
      {_, _, false, _} -> {:error, :invalid_path}
      {_, false, _, _} -> {:error, :invalid_subject}
      {_, _, _, false} -> {:error, :invalid_signature}
      {true, true, true, true} -> :ok
    end
  end

  # TODO: Actually cache
  @spec fetch(String.t) :: {:ok, String.t} | {atom(), atom()}
  def fetch(pem_url) do
    client = Application.get_env(:less_verifies_alexa, :http_client, HTTPotion)

    ets_table = :ets.new(:alexa_pems, [])
    %{body: body, status_code: status} = client.get(pem_url)

    case status in [200, 201] do
      true ->
        :ets.insert(ets_table, {pem_url, body})
        {:ok, body}
      false ->
        {:error, body}
    end
  end

  defp check_cert_path(certs) do
    our_certs = Enum.reverse(certs)
    ca_certs = :certifi.cacerts

    Enum.any? ca_certs, fn (trusted) ->
      {status, _details} = :public_key.pkix_path_validation(trusted, our_certs, [])
      status == :ok
    end
  end

  defp get_cert_value({:Certificate, value, :not_encrypted}), do: value
  defp decode_cert(cert) do
    cert
      |> :public_key.pkix_decode_cert(:otp)
      |> get_field(:tbsCertificate)
  end

  defp extension(cert, ext_id) do
    ext = cert
      |> get_field(:extensions)
      |> Enum.find(fn (ext) ->
        elem(ext, 0) == :Extension &&
          get_field(ext, :extnID) === ext_id
      end)

    case ext do
      nil -> nil
      _ -> get_field(ext, :extnValue)
    end
  end

  defp validity(cert) do
    {:Validity, {:utcTime, from}, {:utcTime, to}} = cert
      |> get_field(:validity)

    convert = fn (time) ->
      time |> to_string() |> parse_date
    end

    {convert.(from), convert.(to)}
  end

  defp parse_date(date_string) do
    date_r = ~r/(?<y>\d\d)(?<mo>\d\d)(?<d>\d\d)(?<h>\d\d)(?<min>\d\d)(?<s>\d\d)Z/
    date_r
      |> Regex.named_captures(date_string)
      |> captures_to_datetime
  end

  defp captures_to_datetime(nil), do: raise "Bad date string in certificate"
  defp captures_to_datetime(captures) do
    captures = Enum.map(captures, fn ({k,v}) -> {String.to_atom(k), String.to_integer(v)} end)
    {:ok, dt} = NaiveDateTime.new(
      2000 + captures[:y],
      captures[:mo],
      captures[:d],
      captures[:h],
      captures[:min],
      captures[:s]
    )
    dt
  end

  defp get_field(record, field) do
    record_type = elem(record, 0)
    idx = @pubkey_schema[record_type]
      |> Keyword.keys
      |> Enum.find_index(&(&1 == field))

    elem(record, idx + 1)
  end

  defp check_san(certs) do
    cert = Enum.find certs, fn (cert) ->
      alt_name = extension(cert, @subject_altname_id)
      alt_name[:dNSName] == 'echo-api.amazon.com'
    end
    cert != nil
  end

  defp check_cert_dates(certs) do
    Enum.all? certs, fn (cert) ->
      {from, to} = validity(cert)
      now = NaiveDateTime.utc_now

      NaiveDateTime.diff(now, from) > 0 &&
        NaiveDateTime.diff(to, now) > 0
    end
  end

  defp public_key(cert) do
    cert
      |> get_field(:subjectPublicKeyInfo)
      |> get_field(:subjectPublicKey)
  end

  defp confirm_payload_signature(cert, req_signature, raw_body) do
    :public_key.verify(
      raw_body,
      :sha,
      Base.decode64!(req_signature, ignore: :whitespace),
      public_key(cert)
    )
  end
end
