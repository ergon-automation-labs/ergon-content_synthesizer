defmodule BotArmyContentSynthesizer.Handlers.SynthesisHandler do
  @moduledoc """
  The "Soul" of the Content Synthesizer.
  Distills raw technical events into " la- la- la" architectural insights.
  """
  require Logger

  @prompt_template """
  You are the 'Sovereign Architect's Content Synthesizer'. Your goal is to turn raw technical/operational events into high-signal, high-impact content.

  The Voice:
  - High-end SRE meets Cyberpunk Philosopher.
  - Direct, rigorous, slightly irreverent, and deeply empathetic to the ADHD 'fog'.
  - Focuses on 'systems over willpower' and 'infrastructure over discipline'.
  - Avoids corporate jargon; prefers ' la- la- la' flow and 'Sovereign' terminology.

  The Event:
  Type: %{type}
  Data: %{data}

  Please generate three distinct versions of this insight:
  1. THE PUNCHY (LinkedIn/X style): A sharp, counter-intuitive take. Start with the failure, end with the architectural fix.
  2. THE PHILOSOPHICAL (Blog/Newsletter style): A reflection on the 'Sovereign' shift. How this mistake reflects a broader truth about cognitive load or systems design.
  3. THE DEV LOG (Technical style): A 'before and after' look at the code/process change.

  Return the result as a JSON object with keys: 'punchy', 'philosophical', 'dev_log'.
  """

  @spec handle_event(atom(), map()) :: {:ok, atom()} | {:error, any()}
  def handle_event(type, payload) do
    Logger.info("[Synthesis] Processing #{type} event...")

    case synthesize_insight(type, payload) do
      {:ok, drafts} ->
        send_to_inbox(drafts)
        {:ok, :synthesized}

      {:error, reason} ->
        Logger.error("[Synthesis] Failed to synthesize insight: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec synthesize_insight(atom(), map()) :: {:ok, map()} | {:error, any()}
  defp synthesize_insight(type, payload) do
    prompt =
      %{type: type, data: payload}
      |> render_prompt()

    # We use the bot's HTTP client to hit the llm_proxy
    case BotArmyContentSynthesizer.HTTPClient.Req.post("/v1/messages", %{
           model: "claude-3-5-sonnet-20240620",
           messages: [%{role: "user", content: prompt}]
         }) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"content" => [%{"text" => content}]}} ->
            parse_json_content(content)

          {:ok, response} ->
            {:error, "Unexpected LLM response format: #{inspect(response)}"}

          {:error, reason} ->
            {:error, "Failed to decode LLM response: #{inspect(reason)}"}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "LLM proxy returned status #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_json_content(content) do
    case Jason.decode(content) do
      {:ok, decoded} -> {:ok, decoded}
      _ -> {:error, "LLM response content was not valid JSON"}
    end
  end

  defp render_prompt(vars) do
    Enum.reduce(vars, @prompt_template, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", inspect(v))
    end)
  end

  defp send_to_inbox(drafts) do
    payload = %{
      "tenant_id" => "default",
      "user_id" => "abby",
      "category" => "content_drafts",
      "status" => "unread",
      "message" => "Sovereign Insight Generated: #{drafts["punchy"]}",
      "metadata" => drafts
    }

    try do
      conn = GenServer.call(BotArmyLibraryRuntime.NATS.Connection, :get_connection)
      Gnat.pub(conn, "inbox.message.create", Jason.encode!(payload))
      Logger.info("[Synthesis] Drafts delivered to Unified Inbox.")
    rescue
      e ->
        Logger.error("[Synthesis] Failed to deliver to inbox: #{inspect(e)}")
    end
  end
end
