defmodule LessVerifiesAlexa.FakeHTTPotion do
  @moduledoc """
  A fake HTTPotion module for use during testing.
  """
  @spec get(String.t) :: %{body: String.t, status_code: integer()}
  def get("https://fail.com"), do: %{status_code: 404, body: "NOT FOUND"}
  def get(url) do
    %{body: "FAKE RESPONSE FOR: " <> url, status_code: 200}
  end
end
