defmodule Minesweeper.RendererTest do
  use ExUnit.Case, async: true

  alias Minesweeper.{Board, Renderer}

  # 盤面（M が地雷、数字は周囲の地雷の数）:
  #   y=0: M 1 0
  #   y=1: 1 1 0
  setup do
    %{board: Board.from_mines(3, 2, [{0, 0}])}
  end

  describe "cell_symbol/2" do
    test "閉じているマスは #", %{board: board} do
      assert Renderer.cell_symbol(board, {1, 0}) == "#"
    end

    test "閉じている地雷も #（開くまで地雷だと分からない）", %{board: board} do
      assert Renderer.cell_symbol(board, {0, 0}) == "#"
    end

    test "旗を立てたマスは F", %{board: board} do
      board = Board.toggle_flag(board, {1, 0})

      assert Renderer.cell_symbol(board, {1, 0}) == "F"
    end

    test "旗を立てた地雷も F（地雷だとばれない）", %{board: board} do
      board = Board.toggle_flag(board, {0, 0})

      assert Renderer.cell_symbol(board, {0, 0}) == "F"
    end

    test "開いた地雷は *", %{board: board} do
      board = Board.reveal(board, {0, 0})

      assert Renderer.cell_symbol(board, {0, 0}) == "*"
    end

    test "開いた数字のマスは、周囲の地雷の数", %{board: board} do
      board = Board.reveal(board, {1, 1})

      assert Renderer.cell_symbol(board, {1, 1}) == "1"
    end

    test "開いた 0 のマスは .", %{board: board} do
      board = Board.reveal(board, {2, 0})

      assert Renderer.cell_symbol(board, {2, 0}) == "."
    end
  end

  describe "render/1" do
    test "座標の見出し付きで盤面全体を表示する", %{board: board} do
      # {2, 1} は 0 なので、周りの {1, 0}, {2, 0}, {1, 1} も連鎖して開きます。
      board = Board.reveal(board, {2, 1})

      expected =
        Enum.join(
          [
            "     0  1  2",
            "  0  #  1  .",
            "  1  #  1  ."
          ],
          "\n"
        )

      assert Renderer.render(board) == expected
    end
  end
end
