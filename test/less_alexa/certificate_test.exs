defmodule LessVerifiesAlexa.CertificateTest do
  use ExUnit.Case
  alias LessVerifiesAlexa.Certificate

  test "it fetches a PEM by calling an HTTP client" do
    {:ok, pem} = Certificate.fetch("https://google.com")
    assert pem == "FAKE RESPONSE FOR: https://google.com"
  end

  test "it fetches a PEM and fails" do
    {:error, _} = Certificate.fetch("https://fail.com")
  end

  test "it validates an actual Alexa Request" do
    {signature, pem, raw_body} = data("amazon.pem")
    assert :ok == Certificate.valid?(signature, pem, raw_body)
  end

  test "it flunks a request with an expired cert" do
    {signature, pem, raw_body} = data("expired.pem")
    assert {:error, :invalid_dates} ==
      Certificate.valid?(signature, pem, raw_body)
  end

  test "it flunks a request with a non-amazon PEM" do
    {signature, pem, raw_body} = data("not_amazon.pem")
    assert {:error, :invalid_subject} ==
      Certificate.valid?(signature, pem, raw_body)
  end

  test "it flunks a request with a self-signed cert" do
    {signature, pem, raw_body} = data("self_signed.pem")
    assert {:error, :invalid_path} ==
      Certificate.valid?(signature, pem, raw_body)
  end

  test "it flunks a request with the wrong signature" do
    {_signature, pem, raw_body} = data("amazon.pem")
    assert {:error, :invalid_signature} ==
      Certificate.valid?("Xc2H0fRiBwDF", pem, raw_body)
  end

  defp data(pem) do
    {:ok, pem} = File.read("test/fixtures/" <> pem)
    {:ok, raw_body} = File.read("test/fixtures/request_body.json")
    {:ok, signature} = File.read("test/fixtures/signature.txt")

    signature = String.trim(signature)
    raw_body = String.trim(raw_body)
    {signature, pem, raw_body}
  end
end
