defmodule Minesweeper.Board do
  @moduledoc """
  マインスイーパーの盤面を表すモジュール。

  Elixir にはクラスがありません。「データ（構造体）」と「関数（モジュール）」を分けて考えます。
  Dart でいう `class Board { ... }` の代わりに、
  - データ → `defstruct` で定義する構造体 `%Minesweeper.Board{}`
  - 振る舞い → このモジュールに定義する関数
  という組み合わせで表現します。
  """

  # 構造体の定義。Dart のフィールド宣言に相当します。
  # 構造体は %Minesweeper.Board{width: 5, height: 5, cells: %{...}} のように書きます。
  defstruct [:width, :height, :cells]

  @doc """
  幅 `width`・高さ `height` の盤面を作り、地雷を `mine_count` 個ランダムに配置します。
  """
  # `def` は公開関数、`defp` は非公開関数（Dart の `_` 始まりの名前に相当）です。
  # Elixir の関数は、最後に評価された式が戻り値になります（`return` はありません）。
  def new(width, height, mine_count) do
    positions = all_positions(width, height)

    mine_positions = Enum.take_random(positions, mine_count)

    from_mines(width, height, mine_positions)
  end

  @doc """
  地雷の位置を指定して盤面を作ります。

  `new/3` は地雷をランダムに置くのでテストしづらいため、
  テストではこちらを使って「どこに地雷があるか」を固定します。

  例: `from_mines(3, 3, [{1, 1}])` は真ん中だけに地雷がある 3×3 の盤面を作ります。
  """
  def from_mines(width, height, mine_positions) do
    cells = build_cells(all_positions(width, height), MapSet.new(mine_positions))

    # `__MODULE__` は、このモジュール自身（Minesweeper.Board）を指します。
    %__MODULE__{width: width, height: height, cells: cells}
  end

  @doc """
  座標 `{x, y}` の周囲8マスにある地雷の数を返します。
  """
  # 引数に `{x, y}` と書くと、渡されたタプルがその場で分解されます（パターンマッチ）。
  # Dart 3 の `void f((int, int) p) { var (x, y) = p; }` を引数の位置で直接やっているイメージです。
  #
  # パイプ演算子 `|>` は「左の値を、右の関数の第1引数として渡す」という意味です。
  # 下の処理は `Enum.count(neighbors({x, y}), fn ... end)` と同じですが、上から下へ読めます。
  def adjacent_mines(board, {x, y}) do
    {x, y}
    |> neighbors()
    |> Enum.count(fn position -> mine?(board, position) end)
  end

  @doc """
  座標 `position` のマスを開いた、新しい盤面を返します。

  - 盤面の外の座標や、すでに開いているマスを指定したときは、盤面をそのまま返します。
  - 地雷のマスも開きます（ゲームオーバーの判定は後のタスクで作ります）。
  - 開いたマスが地雷ではなく、周囲の地雷が 0 個なら、周囲8マスも自動で開きます。
    開いたマスがまた 0 なら、さらにその周りへと連鎖していきます。
  """
  # Elixir のデータはイミュータブル（変更不可）です。
  # なので reveal は「渡された board を書き換える」のではなく、
  # 「一部だけ違う新しい board を作って返す」関数になります。
  # 呼び出し側は `board = Board.reveal(board, {1, 1})` のように、戻り値を受け取って使います。
  def reveal(board, position) do
    # `case` の節には、値だけでなく「形」も書けます。
    # `%{state: :revealed}` は「state キーの値が :revealed であるマップ」に一致します。
    # マップのパターンは部分一致なので、mine キーなど他のキーがあってもかまいません。
    case Map.get(board.cells, position) do
      nil ->
        board

      %{state: :revealed} ->
        board

      cell ->
        board = reveal_cell(board, position)

        # Elixir の `if` は「式」なので、値を返します（Dart の三項演算子 `? :` に近いものです）。
        # この if の結果が、そのまま reveal/2 の戻り値になります。
        if not cell.mine and adjacent_mines(board, position) == 0 do
          reveal_neighbors(board, position)
        else
          board
        end
    end
  end

  # position の周囲8マスを、順番に reveal/2 で開いた盤面を返します。
  #
  # reveal/2 → reveal_neighbors/2 → reveal/2 → ... と、関数が自分自身を（間接的に）呼んでいます。
  # これが「再帰」です。Elixir には while もミュータブルな変数もないので、繰り返しは再帰で書きます。
  #
  # 無限に続かないのは、reveal/2 が「盤面の外」と「すでに開いているマス」では
  # board をそのまま返して止まるからです（これを再帰の「終了条件」と呼びます）。
  defp reveal_neighbors(board, position) do
    # Enum.reduce(list, 初期値, fn 要素, 今までの結果 -> 新しい結果 end) は Dart の fold と同じです
    # （引数の順番は逆で、要素が先・結果が後）。ここでは board を受け渡しながら1マスずつ開きます。
    Enum.reduce(neighbors(position), board, fn neighbor, acc -> reveal(acc, neighbor) end)
  end

  # position のセルの state を :revealed にした、新しい盤面を返します。
  # （position が盤面の中にあり、まだ閉じていることは reveal/2 で確認済みです）
  defp reveal_cell(board, position) do
    # 内側から順に作り直します: セルを更新 → cells を更新 → board の cells を差し替え。
    # `%{map | key: value}` は「key だけ value にしたコピー」を作ります（Dart の copyWith に近いもの）。
    new_cells = Map.update!(board.cells, position, fn v -> %{v | state: :revealed} end)
    %{board | cells: new_cells}

    # 参考までに
    # `|>` は左の値を右の関数の「第1引数」に入れます。
    # `%{board | cells: ...}` は関数ではないのでそのままではつなげず、
    # `then/2`（値を受け取る無名関数を呼ぶだけの関数）で包んでいます。
    # board.cells
    # |> Map.update!(position, fn cell -> %{cell | state: :revealed} end)
    # |> then(fn cells -> %{board | cells: cells} end)
  end

  # その座標に地雷があれば true を返します。
  # 盤面の外（例: {-1, 0}）を渡すと Map.get は nil を返すので、その場合は false にします。
  #
  # `case` は値をパターンで振り分けます（Dart 3 の switch 式に近いものです）。
  # 上から順に照合し、最初に一致した節が実行されます。
  defp mine?(board, position) do
    case Map.get(board.cells, position) do
      nil -> false
      cell -> cell.mine
    end
  end

  # 座標 {x, y} の周囲8マスの座標をリストで返します（盤面の外の座標も含んでかまいません）。
  #
  # 例: neighbors({1, 1}) #=> [{0, 0}, {0, 1}, {0, 2}, {1, 0}, {1, 2}, {2, 0}, {2, 1}, {2, 2}]
  #
  # `for` の `<-` を2つ並べると二重ループ、その後ろの条件式はフィルタになります。
  # フィルタが false になる組み合わせ（ここでは自分自身の座標）は結果に入りません。
  defp neighbors({x, y}) do
    for nx <- (x - 1)..(x + 1), ny <- (y - 1)..(y + 1), {nx, ny} != {x, y}, do: {nx, ny}
  end

  # 盤面上の全座標を {x, y} というタプルのリストで返します。
  # `for` は「内包表記」で、Dart の `[for (var y ...) for (var x ...) (x, y)]` に近いものです。
  # 例: all_positions(2, 2) #=> [{0, 0}, {1, 0}, {0, 1}, {1, 1}]
  defp all_positions(width, height) do
    for y <- 0..(height - 1), x <- 0..(width - 1), do: {x, y}
  end

  # 各座標をキー、セルを値とする Map を作ります。
  #
  # 結果の例（地雷が {1, 0} だけの場合）:
  #   %{
  #     {0, 0} => %{mine: false, state: :hidden},
  #     {1, 0} => %{mine: true,  state: :hidden},
  #     ...
  #   }
  #
  # `:hidden` は「アトム」という値です。名前そのものが値になる定数で、Dart の enum に近い使い方をします。
  #
  # `Map.new(list, fn ...)` は、リストの各要素を {キー, 値} のタプルに変換して Map を作ります。
  # 無名関数は `fn 引数 -> 本体 end` と書きます（Dart の `(引数) => 本体` に相当）。
  defp build_cells(positions, mine_positions) do
    Map.new(positions, fn position ->
      {position, %{mine: MapSet.member?(mine_positions, position), state: :hidden}}
    end)
  end
end
