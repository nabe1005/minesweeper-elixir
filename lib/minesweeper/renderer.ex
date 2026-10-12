defmodule Minesweeper.Renderer do
  @moduledoc """
  盤面をターミナル表示用の文字列にするモジュール。

  画面への出力（IO.puts）はここでは行わず、「盤面 → 文字列」の変換だけを担当します。
  入出力を含まない関数は、同じ入力に対して必ず同じ結果を返すので、テストしやすくなります。

  表示例（地雷が {0, 0} にある 3×2 の盤面で、{2, 1} を開いた後）:

           0  1  2
        0  #  1  .
        1  #  1  .

  記号の意味:
  - `#` 閉じているマス
  - `F` 旗を立てたマス
  - `*` 開いた地雷
  - `.` 開いていて、周囲の地雷が 0 個のマス
  - `1`〜`8` 開いていて、周囲の地雷がその個数のマス
  """

  alias Minesweeper.Board

  # 1マスぶんの表示幅（文字数）。座標が 2 桁になっても列がずれないように 3 にしています。
  @cell_width 3

  @doc """
  盤面を、1行目に x 座標、各行の先頭に y 座標を付けた文字列にします。
  """
  @spec render(Board.t()) :: String.t()
  def render(board) do
    xs = 0..(board.width - 1)
    ys = 0..(board.height - 1)

    # Enum.map_join(enumerable, 区切り文字, fn ...) は「map してから join」を一度に行います。
    # 例: Enum.map_join([1, 2, 3], "-", fn n -> "#{n * 10}" end) #=> "10-20-30"
    # Dart の `list.map(...).join(区切り)` と同じです。
    header = pad("") <> Enum.map_join(xs, "", &pad/1)

    rows =
      Enum.map(ys, fn y ->
        pad(y) <> Enum.map_join(xs, "", fn x -> pad(cell_symbol(board, {x, y})) end)
      end)

    # `[a | list]` は「list の先頭に a を付け足した新しいリスト」です。
    Enum.join([header | rows], "\n")
  end

  @doc """
  座標 `position` のマスを表す1文字を返します。
  """
  @spec cell_symbol(Board.t(), Board.position()) :: String.t()
  def cell_symbol(board, position) do
    # 節は上から順に照合されます。閉じている地雷や旗を立てた地雷を "*" と表示しないよう、
    # :hidden と :flagged の節を、地雷の節より先に置いています。
    case board.cells[position] do
      %{state: :hidden} -> "#"
      %{state: :flagged} -> "F"
      %{mine: true} -> "*"
      _cell -> number_symbol(Board.adjacent_mines(board, position))
    end
  end

  # 周囲の地雷の数を、表示する文字に変えます。0 のときだけ "." にします。
  #
  # 関数節の引数には、0 のような値そのもの（リテラル）も書けます。
  # 上から順に照合されるので、0 なら1つ目、それ以外は2つ目の節が実行されます。
  defp number_symbol(0), do: "."
  defp number_symbol(count), do: Integer.to_string(count)

  # 値を文字列にして、左側を空白で埋めて @cell_width 文字にそろえます。
  # 例: pad(7) #=> "  7"
  defp pad(value), do: value |> to_string() |> String.pad_leading(@cell_width)
end
