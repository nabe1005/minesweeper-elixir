defmodule Minesweeper.Game do
  @moduledoc """
  1回分のゲームを表すモジュール。

  盤面（`Minesweeper.Board`）と、ゲームの状態（プレイ中・勝ち・負け）をまとめて持ちます。
  Board は「盤面のルール」だけ、Game は「勝ち負けの進行」だけを担当するように分けています。
  """

  alias Minesweeper.Board

  # `status: :playing` のように書くと、そのフィールドの初期値になります。
  # status は :playing（プレイ中）、:won（勝ち）、:lost（負け）のどれかです。
  defstruct [:board, status: :playing]

  @type status :: :playing | :won | :lost

  # 他のモジュールの型は `モジュール名.型名()` で使えます。alias があるので Board.t() と書けます。
  @type t :: %__MODULE__{board: Board.t(), status: status()}

  @doc """
  盤面 `board` から、プレイ中のゲームを作ります。
  """
  @spec new(Board.t()) :: t()
  def new(board) do
    %__MODULE__{board: board}
  end

  @doc """
  座標 `position` のマスを開きます。

  - プレイ中なら `{:ok, 新しいゲーム}` を返します。
  - すでに終わったゲーム（勝ち・負け）なら `{:error, :game_finished}` を返します。
  """
  # 成功・失敗を `{:ok, 値}` / `{:error, 理由}` のタプルで返すのは、Elixir の定番の書き方です。
  # 例外を投げる代わりに、呼び出し側が case でパターンマッチして振り分けます。
  #   case Game.reveal(game, {0, 0}) do
  #     {:ok, game} -> ...
  #     {:error, :game_finished} -> ...
  #   end
  #
  # Elixir では、同じ名前・同じ引数の数の関数を何個も並べて書けます（「関数節」と呼びます）。
  # 呼び出されると上から順に引数をパターンマッチして、最初に一致した節が実行されます。
  # Dart で関数の先頭に if を並べて振り分けていたことを、関数の定義そのもので書けるイメージです。
  #
  # `%__MODULE__{status: :playing} = game` は
  # 「引数が status: :playing の Game 構造体なら一致し、その引数全体を game という名前で受け取る」
  # という意味です。
  #
  # 関数節が複数あっても @spec は1つだけ書き、すべての節をまとめた型にします。
  @spec reveal(t(), Board.position()) :: {:ok, t()} | {:error, :game_finished}
  def reveal(%__MODULE__{status: :playing} = game, position) do
    board = Board.reveal(game.board, position)

    {:ok, %{game | board: board, status: next_status(board, position)}}
  end

  # 上の節に一致しなかった＝ゲームが終わっている場合です。
  # 中身が1行の関数は `def 関数名(引数), do: 戻り値` と1行で書けます。
  # `%__MODULE__{}` は「中身は何でもいいが Game 構造体であること」というパターンです。
  # Game 以外の値が渡されたら、ごまかさずに FunctionClauseError で落とします（let it crash）。
  def reveal(%__MODULE__{}, _position), do: {:error, :game_finished}

  @doc """
  座標 `position` のマスのフラグを切り替えます。

  - プレイ中なら `{:ok, 新しいゲーム}` を返します。
  - すでに終わったゲーム（勝ち・負け）なら `{:error, :game_finished}` を返します。
  """
  # reveal/2 と同じく、関数節で status を振り分けて {:ok, _} / {:error, _} を返します。
  # 旗では勝ち負けは変わらないので、status はそのままにしています。
  @spec toggle_flag(t(), Board.position()) :: {:ok, t()} | {:error, :game_finished}
  def toggle_flag(%__MODULE__{status: :playing} = game, position) do
    board = Board.toggle_flag(game.board, position)

    {:ok, %{game | board: board}}
  end

  def toggle_flag(%__MODULE__{}, _position), do: {:error, :game_finished}

  # 開いた結果から、次のゲームの状態を決めます。
  #
  # `cond` は「上から順に条件を調べて、最初に true になった節を実行する」構文です。
  # Dart の if / else if / else の連鎖に相当します。最後の `true ->` が else の役割です。
  defp next_status(board, position) do
    cond do
      Board.mine?(board, position) -> :lost
      Board.cleared?(board) -> :won
      true -> :playing
    end
  end
end
