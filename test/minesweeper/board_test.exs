defmodule Minesweeper.BoardTest do
  # ExUnit は Elixir 標準のテストフレームワークです（Dart の package:test に相当）。
  use ExUnit.Case, async: true

  # `alias` を書くと、Minesweeper.Board を Board と短く書けるようになります。
  alias Minesweeper.Board

  describe "new/3" do
    test "指定した幅と高さを持つ" do
      board = Board.new(5, 4, 3)

      assert board.width == 5
      assert board.height == 4
    end

    test "幅 × 高さの数だけセルがある" do
      board = Board.new(5, 4, 3)

      assert map_size(board.cells) == 20
    end

    test "地雷がちょうど mine_count 個ある" do
      board = Board.new(5, 4, 3)

      mine_count = Enum.count(board.cells, fn {_pos, cell} -> cell.mine end)
      assert mine_count == 3
    end

    test "すべてのセルは最初は閉じている" do
      board = Board.new(5, 4, 3)

      assert Enum.all?(board.cells, fn {_pos, cell} -> cell.state == :hidden end)
    end
  end

  describe "from_mines/3" do
    test "指定した位置にだけ地雷がある" do
      board = Board.from_mines(3, 3, [{1, 1}])

      assert board.cells[{1, 1}].mine == true
      assert board.cells[{0, 0}].mine == false
    end
  end

  describe "adjacent_mines/2" do
    # 盤面（M が地雷）:
    #   y=0: M . .
    #   y=1: . . .
    #   y=2: . M M
    setup do
      %{board: Board.from_mines(3, 3, [{0, 0}, {1, 2}, {2, 2}])}
    end

    # `%{board: board}` は setup の戻り値からパターンマッチで board を取り出しています。
    test "真ん中のマスは周囲8マスすべてを数える", %{board: board} do
      assert Board.adjacent_mines(board, {1, 1}) == 3
    end

    test "角のマスは盤面の外を数えない", %{board: board} do
      assert Board.adjacent_mines(board, {2, 0}) == 0
      assert Board.adjacent_mines(board, {0, 2}) == 1
    end

    test "辺のマスも正しく数える", %{board: board} do
      assert Board.adjacent_mines(board, {2, 1}) == 2
    end

    test "自分自身の地雷は数えない", %{board: board} do
      assert Board.adjacent_mines(board, {0, 0}) == 0
      assert Board.adjacent_mines(board, {2, 2}) == 1
    end
  end

  describe "reveal/2" do
    setup do
      %{board: Board.from_mines(3, 3, [{0, 0}])}
    end

    test "指定したマスが開く", %{board: board} do
      board = Board.reveal(board, {1, 1})

      assert board.cells[{1, 1}].state == :revealed
    end

    test "他のマスは閉じたまま", %{board: board} do
      board = Board.reveal(board, {1, 1})

      hidden_count = Enum.count(board.cells, fn {_pos, cell} -> cell.state == :hidden end)
      assert hidden_count == 8
    end

    test "地雷の情報は変わらない", %{board: board} do
      board = Board.reveal(board, {0, 0})

      assert board.cells[{0, 0}] == %{mine: true, state: :revealed}
    end

    # イミュータブルなので、reveal に渡した元の board は変わりません。
    test "元の盤面は変わらない", %{board: board} do
      _new_board = Board.reveal(board, {1, 1})

      assert board.cells[{1, 1}].state == :hidden
    end

    test "盤面の外を指定しても何も起きない", %{board: board} do
      assert Board.reveal(board, {5, 5}) == board
    end

    test "同じマスを2回開いても結果は同じ", %{board: board} do
      once = Board.reveal(board, {1, 1})

      assert Board.reveal(once, {1, 1}) == once
    end
  end

  describe "reveal/2 の連鎖" do
    # 開いているマスの座標を集めるヘルパー。テストを読みやすくするために使います。
    defp revealed_positions(board) do
      for {pos, %{state: :revealed}} <- board.cells, into: MapSet.new(), do: pos
    end

    # 盤面（M が地雷、数字は周囲の地雷の数）:
    #   y=0: 0 0 0 0
    #   y=1: 0 0 0 0
    #   y=2: 0 0 1 1
    #   y=3: 0 0 1 M
    test "0 のマスを開くと、地雷以外のマスがすべて開く" do
      board = Board.from_mines(4, 4, [{3, 3}]) |> Board.reveal({0, 0})

      assert MapSet.size(revealed_positions(board)) == 15
      assert board.cells[{3, 3}].state == :hidden
    end

    test "数字のマスを開いても連鎖しない" do
      board = Board.from_mines(4, 4, [{3, 3}]) |> Board.reveal({2, 2})

      assert revealed_positions(board) == MapSet.new([{2, 2}])
    end

    # 盤面（真ん中の列が地雷の壁）:
    #   y=0: 0 2 M 2 0
    #   y=1: 0 3 M 3 0
    #   y=2: 0 2 M 2 0
    test "連鎖は数字のマスで止まり、壁の向こうには広がらない" do
      board = Board.from_mines(5, 3, [{2, 0}, {2, 1}, {2, 2}]) |> Board.reveal({0, 0})

      expected = MapSet.new([{0, 0}, {0, 1}, {0, 2}, {1, 0}, {1, 1}, {1, 2}])
      assert revealed_positions(board) == expected
    end

    # 地雷のマスは、周囲に地雷がなくても連鎖させません。
    test "地雷のマスを開いても連鎖しない" do
      board = Board.from_mines(3, 3, [{0, 0}]) |> Board.reveal({0, 0})

      assert revealed_positions(board) == MapSet.new([{0, 0}])
    end
  end

  describe "cleared?/1" do
    # 盤面: 地雷が {0, 0} にだけある 3×1 の盤面
    #   y=0: M 1 0
    setup do
      %{board: Board.from_mines(3, 1, [{0, 0}])}
    end

    test "最初はクリアしていない", %{board: board} do
      refute Board.cleared?(board)
    end

    test "地雷以外をすべて開くとクリア", %{board: board} do
      # {2, 0} は周囲の地雷が 0 なので、{1, 0} も連鎖して開きます。
      board = Board.reveal(board, {2, 0})

      assert Board.cleared?(board)
    end

    test "地雷以外に閉じたマスが残っていればクリアではない", %{board: board} do
      board = Board.reveal(board, {1, 0})

      refute Board.cleared?(board)
    end

    test "地雷を開いても、他のマスが残っていればクリアではない", %{board: board} do
      board = Board.reveal(board, {0, 0})

      refute Board.cleared?(board)
    end
  end

  describe "toggle_flag/2" do
    setup do
      %{board: Board.from_mines(3, 3, [{0, 0}])}
    end

    test "閉じているマスに旗を立てる", %{board: board} do
      board = Board.toggle_flag(board, {1, 1})

      assert board.cells[{1, 1}].state == :flagged
    end

    test "もう一度呼ぶと旗が外れる", %{board: board} do
      board = board |> Board.toggle_flag({1, 1}) |> Board.toggle_flag({1, 1})

      assert board.cells[{1, 1}].state == :hidden
    end

    test "地雷のマスにも旗を立てられる", %{board: board} do
      board = Board.toggle_flag(board, {0, 0})

      assert board.cells[{0, 0}] == %{mine: true, state: :flagged}
    end

    test "開いているマスには旗を立てられない", %{board: board} do
      board = Board.reveal(board, {1, 1})

      assert Board.toggle_flag(board, {1, 1}) == board
    end

    test "盤面の外を指定しても何も起きない", %{board: board} do
      assert Board.toggle_flag(board, {9, 9}) == board
    end
  end

  describe "reveal/2 と旗" do
    test "旗を立てたマスは開かない" do
      board = Board.from_mines(3, 3, [{0, 0}]) |> Board.toggle_flag({1, 1})

      assert Board.reveal(board, {1, 1}) == board
    end

    # 盤面（M が地雷、F が旗）:
    #   y=0: 0 0 0 0
    #   y=1: 0 0 0 0
    #   y=2: 0 0 1 1
    #   y=3: F 0 1 M
    test "連鎖で開くときも、旗を立てたマスは開かない" do
      board =
        Board.from_mines(4, 4, [{3, 3}])
        |> Board.toggle_flag({0, 3})
        |> Board.reveal({0, 0})

      assert board.cells[{0, 3}].state == :flagged
      assert Enum.count(board.cells, fn {_pos, cell} -> cell.state == :revealed end) == 14
    end
  end
end
