defmodule CheckerMal.DiscordWebook do
  require Logger

  @webook_url Application.compile_env(:checker_mal, :send_errors_to_discord_webhook)

  def send_error(error) when is_bitstring(error) do
    cond do
      is_nil(@webook_url) ->
        Logger.warning("No discord webhook set, not sending error")

      @webook_url == "" ->
        Logger.warning("No discord webhook set, not sending error")

      true ->
        send_error(error, @webook_url)
    end
  end

  def send_error(error, webhook_url) when is_bitstring(error) do
    Logger.error("Sending error to discord webhook")
    Logger.warning(error)

    body = %{
      embeds: [
        %{
          title: "Unapproved Indexing Error",
          description: "```#{error}```"
        }
      ]
    }

    HTTPoison.post(webhook_url, Jason.encode!(body), [{"Content-Type", "application/json"}])
  end
end
