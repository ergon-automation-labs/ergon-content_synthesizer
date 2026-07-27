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

  defp synthesize_insight(type, payload) do
    prompt =
      %{type: type, data: payload}
      |> render_prompt()

    # We use the bot's HTTP client to hit the llm_proxy
    case BotArmyContentSynthesizer.HttpClient.post("/v1/messages", %{
           # Default to a high-reasoning model
           model: "claude-3-5-sonnet-20240620",
           messages: [%{role: "user", content: prompt}]
         }) do
      {:ok, %{"data" => data}} ->
        # The proxy usually returns a complex object, we want the content of the first message
        content = data["content"][0]["text"]

        case Jason.decode(content) do
          {:ok, decoded} -> {:ok, decoded}
          _ -> {:error, "LLM response was not valid JSON"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp render_prompt(vars) do
    # Simple interpolation of the template
    Enum.reduce(vars, @prompt_template, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", inspect(v))
    end)
  end

  defp send_to_inbox(drafts) do
    # Send to the BotArmyInbox system
    payload = %{
      "tenant_id" => "default",
      "user_id" => "abby",
      "category" => "content_drafts",
      "status" => "unread",
      "message" => "Sovereign Insight Generated: #{drafts["punchy"]}",
      "metadata" => drafts
    }

    # Use the runtime NATS connection to publish the a-priori request
    case BotArmyLibraryRuntime.NATS.Connection.get_connection() do
      {:ok, conn} ->
        Gnat.pub(conn, "inbox.message.create", Jason.encode!(payload))
        Logger.info("[Synthesis] Drafts delivered to Unified Inbox.")

      {:error, reason} ->
        Logger.error("[Synthesis] Failed to deliver to inbox: #{inspect(reason)}")
    end
  end
end
