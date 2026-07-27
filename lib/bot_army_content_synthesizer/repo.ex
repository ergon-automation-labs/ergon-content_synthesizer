defmodule BotArmyContentSynthesizer.Repo do
  use Ecto.Repo,
    otp_app: :bot_army_content_synthesizer,
    adapter: Ecto.Adapters.Postgres
end
