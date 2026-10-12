defmodule Minesweeper.GameTest do
  use ExUnit.Case, async: true

  alias Minesweeper.{Board, Game}

  # 盤面（M が地雷、数字は周囲の地雷の数）:
  #   y=0: 0 0 0 0
  #   y=1: 0 0 0 0
  #   y=2: 0 0 1 1
  #   y=3: 0 0 1 M
  setup do
    %{game: Game.new(Board.from_mines(4, 4, [{3, 3}]))}
  end

  test "新しいゲームはプレイ中", %{game: game} do
    assert game.status == :playing
  end

  test "数字のマスを開くと、プレイ中のまま", %{game: game} do
    # `{:ok, game} = ...` は、戻り値が {:ok, _} の形なら game を取り出します。
    # 形が違う（{:error, _} など）とその場でエラーになるので、テストでもよく使います。
    {:ok, game} = Game.reveal(game, {2, 2})

    assert game.status == :playing
    assert game.board.cells[{2, 2}].state == :revealed
  end

  test "地雷を開くと負け", %{game: game} do
    {:ok, game} = Game.reveal(game, {3, 3})

    assert game.status == :lost
  end

  test "地雷以外のマスをすべて開くと勝ち", %{game: game} do
    # {0, 0} から連鎖して、地雷以外の 15 マスが一度に開きます。
    {:ok, game} = Game.reveal(game, {0, 0})

    assert game.status == :won
  end

  test "盤面の外を開いても、プレイ中のまま", %{game: game} do
    assert {:ok, %Game{status: :playing}} = Game.reveal(game, {9, 9})
  end

  test "負けたあとは開けない", %{game: game} do
    {:ok, game} = Game.reveal(game, {3, 3})

    assert Game.reveal(game, {0, 0}) == {:error, :game_finished}
  end

  test "勝ったあとは開けない", %{game: game} do
    {:ok, game} = Game.reveal(game, {0, 0})

    assert Game.reveal(game, {3, 3}) == {:error, :game_finished}
  end

  describe "toggle_flag/2" do
    test "プレイ中なら旗を立てられ、状態はプレイ中のまま", %{game: game} do
      {:ok, game} = Game.toggle_flag(game, {3, 3})

      assert game.board.cells[{3, 3}].state == :flagged
      assert game.status == :playing
    end

    test "終わったゲームでは旗を立てられない", %{game: game} do
      {:ok, game} = Game.reveal(game, {3, 3})

      assert Game.toggle_flag(game, {0, 0}) == {:error, :game_finished}
    end
  end
end
