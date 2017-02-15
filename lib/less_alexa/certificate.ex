defmodule LessAlexa.Certificate do
  require Record

  @pubkey_schema Record.extract_all(from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  @subject_altname_id {2, 5, 29, 17}

  def valid?(params = {req_signature, pem_url, raw_body}) do
    certs = pem_url
      |> fetch_pem()
      |> :public_key.pem_decode()
      |> Enum.map(&get_cert_value/1)
    decoded_certs = Enum.map(certs, &decode_cert/1)

    check_san(decoded_certs) &&
      check_cert_dates(decoded_certs) &&
      confirm_payload_signature(hd(decoded_certs), req_signature, raw_body) &&
      check_cert_path(certs)
  end

  def check_cert_path(certs) do
    our_certs = Enum.reverse(certs)
    ca_certs = :certifi.cacerts

    Enum.any? ca_certs, fn (trusted) ->
      {status, _details } = :public_key.pkix_path_validation(trusted, our_certs, [])
      status == :ok
    end
  end

  def get_cert_value({:Certificate, value, :not_encrypted}), do: value
  def decode_cert(cert) do
    cert
      |> :public_key.pkix_decode_cert(:otp)
      |> get_field(:tbsCertificate)
  end

  defp extension(cert, ext_id) do
    cert
      |> get_field(:extensions)
      |> Enum.find(fn (ext) ->
        elem(ext, 0) == :Extension &&
          get_field(ext, :extnID) == ext_id
      end)
      |> get_field(:extnValue)
  end

  defp validity(cert) do
    {:Validity, {:utcTime, from}, {:utcTime, to}} = cert
      |> get_field(:validity)

    convert = fn (time) ->
      time |> to_string() |> Timex.parse!("%y%m%d%H%M%SZ", :strftime)
    end

    {convert.(from), convert.(to)}
  end

  defp get_field(record, field) do
    record_type = elem(record, 0)
    idx = @pubkey_schema[record_type]
      |> Keyword.keys
      |> Enum.find_index(&(&1 == field))

    elem(record, idx + 1)
  end

  # TODO: Actually cache
  defp fetch_pem(pem_url) do
    ets_table = :ets.new(:alexa_pems, [])
    pem = HTTPotion.get(pem_url).body
    :ets.insert(ets_table, {pem_url, pem})
    pem
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
