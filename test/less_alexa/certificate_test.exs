defmodule LessAlexa.CertificateTest do
  use ExUnit.Case

  test "it fetches a PEM by calling an HTTP client" do
    {:ok, pem} = LessAlexa.Certificate.fetch("https://google.com")
    assert pem == "FAKE RESPONSE FOR: https://google.com"
  end

  test "it fetches a PEM and fails" do
    {:error, _} = LessAlexa.Certificate.fetch("https://fail.com")
  end
end
