defmodule Minesweeper.CLI do
  @moduledoc """
  ターミナルでマインスイーパーを遊ぶためのモジュール。

  `mix minesweeper` で起動します（lib/mix/tasks/minesweeper.ex を参照）。
  """

  alias Minesweeper.{Board, Game, Renderer}

  @prompt "開く座標を「x y」の形で入力してください\n「f x y」でフラグを立てる・外すことができます\n（q で終了）> "

  @doc """
  ランダムな盤面でゲームを始めます。
  """
  # `\\` はデフォルト引数です（Dart の `{int width = 9}` に相当）。
  # start() と引数なしで呼ぶと、9×9・地雷 10 個になります。
  @spec start(pos_integer(), pos_integer(), non_neg_integer()) :: :ok
  def start(width \\ 9, height \\ 9, mine_count \\ 10) do
    Board.new(width, height, mine_count)
    |> Game.new()
    |> play()
  end

  @doc """
  ゲームを、終わるまで繰り返し進めます。

  テストで地雷の位置を固定できるように、Game を受け取る形にしています。
  """
  # Elixir には while がないので、「1手進めて、また自分を呼ぶ」再帰でゲームループを書きます。
  #
  # 関数の最後の処理が自分自身の呼び出しになっている再帰を「末尾再帰」と呼びます。
  # 末尾再帰は内部でただのループに変換されるので、何万回繰り返してもスタックがあふれません。
  # ここでは handle_input/2 → play/1 → handle_input/2 → ... の形で、どれも最後に呼んでいます。
  #
  # 状態（status）ごとに関数節を分けているので、if で分岐を書かずに済んでいます。
  @spec play(Game.t()) :: :ok
  def play(%Game{status: :playing} = game) do
    IO.puts(Renderer.render(game.board))

    # IO.gets はユーザーの入力を1行読みます。改行（"\n"）も含んだ文字列が返ります。
    # Ctrl+D で入力が終わったときは、文字列ではなく :eof が返ります。
    input = IO.gets(@prompt)

    handle_input(game, input)
  end

  def play(%Game{status: :won} = game) do
    IO.puts(Renderer.render(game.board))
    IO.puts("クリア！おめでとうございます 🎉")
  end

  def play(%Game{status: :lost} = game) do
    IO.puts(Renderer.render(game.board))
    IO.puts("地雷を踏みました 💥 ゲームオーバー")
  end

  # 入力に応じて、ゲームを進めるか、終了します。
  defp handle_input(_game, :eof), do: IO.puts("\n終了します。")

  defp handle_input(game, input) do
    # `with` は「上から順にパターンマッチして、全部成功したら do の中を実行する」構文です。
    # 途中で一致しなかったら、その時点の値が else に渡されます。
    # {:ok, ...} を返す処理を何段もつなぐときに、case の入れ子を避けられます。
    with {:ok, {action, position}} <- parse_command(input),
         true <- Map.has_key?(game.board.cells, position),
         {:ok, game} <- apply_action(game, action, position) do
      play(game)
    else
      :quit ->
        IO.puts("終了します。")

      {:error, :invalid_input} ->
        IO.puts("入力の形が正しくありません。例: 3 4（マスを開く）、f 3 4（旗を立てる・外す）")
        play(game)

      false ->
        IO.puts("盤面の外です。")
        play(game)
    end
  end

  # 操作の種類（:flag / :reveal）に応じて、Game の関数を呼び分けます。
  # 引数にアトムを直接書いた関数節で振り分けているので、if は要りません。
  defp apply_action(game, :flag, position) do
    Game.toggle_flag(game, position)
  end

  defp apply_action(game, :reveal, position) do
    Game.reveal(game, position)
  end

  @doc """
  入力された文字列を解釈します。

  - `"3 4\\n"` のような「整数 空白 整数」なら、マスを開く操作 `{:ok, {:reveal, {3, 4}}}`
  - `"f 3 4\\n"` のような「f 整数 空白 整数」なら、旗を立てる・外す操作 `{:ok, {:flag, {3, 4}}}`
  - `"q"` なら `:quit`
  - それ以外は `{:error, :invalid_input}`
  """
  @spec parse_command(String.t()) ::
          {:ok, {:flag | :reveal, Board.position()}} | :quit | {:error, :invalid_input}
  def parse_command(input) do
    case String.trim(input) do
      "q" -> :quit
      "f " <> rest -> parse_numbers(rest, :flag)
      trimmed -> parse_numbers(trimmed, :reveal)
    end
  end

  # "3 4" のような文字列を {:ok, {action, {3, 4}}} にします。形が違えば {:error, :invalid_input} です。
  defp parse_numbers(trimmed, action) do
    # Integer.parse/1 は {整数, 残りの文字列} を返します。パターンに "" を書いて、"12a" のような残りがある入力を弾きます。
    with [num, num2] <- String.split(trimmed),
         {x, ""} <- Integer.parse(num),
         {y, ""} <- Integer.parse(num2) do
      {:ok, {action, {x, y}}}
    else
      _error ->
        {:error, :invalid_input}
    end
  end
end
