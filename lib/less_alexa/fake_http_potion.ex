defmodule LessAlexa.FakeHTTPotion do
  @spec get(String.t) :: {:ok, String.t} | {:error, atom()}
  def get("https://fail.com"), do: {:error, :not_found}
  def get(url) do
    {:ok, %{body: "FAKE RESPONSE FOR: " <> url}}
  end
end
