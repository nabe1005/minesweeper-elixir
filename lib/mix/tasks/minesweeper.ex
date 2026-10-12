defmodule Mix.Tasks.Minesweeper do
  @moduledoc """
  ターミナルでマインスイーパーを遊びます。

      mix minesweeper
  """
  # `Mix.Tasks.〇〇` という名前のモジュールで `use Mix.Task` すると、`mix 〇〇` コマンドになります。
  # mix test や mix format も、同じ仕組みで作られています。
  use Mix.Task

  @shortdoc "ターミナルでマインスイーパーを遊ぶ"

  @impl Mix.Task
  def run(_args) do
    Minesweeper.CLI.start()
  end
end
