defmodule Minesweeper.CLITest do
  use ExUnit.Case, async: true

  # capture_io/2 は、関数の中で IO.puts などが出力した内容を文字列として受け取れる関数です。
  # 第1引数に文字列を渡すと、それを IO.gets への入力として使ってくれます。
  import ExUnit.CaptureIO

  alias Minesweeper.{Board, CLI, Game}

  describe "parse_command/1" do
    test "「整数 空白 整数」はマスを開く操作" do
      assert CLI.parse_command("3 4\n") == {:ok, {:reveal, {3, 4}}}
    end

    test "前後や間の空白が多くても読める" do
      assert CLI.parse_command("  10   2  \n") == {:ok, {:reveal, {10, 2}}}
    end

    test "「f 整数 整数」は旗を立てる・外す操作" do
      assert CLI.parse_command("f 3 4\n") == {:ok, {:flag, {3, 4}}}
    end

    test "q は終了" do
      assert CLI.parse_command("q\n") == :quit
    end

    test "数が1つだけ・3つなら失敗" do
      assert CLI.parse_command("3\n") == {:error, :invalid_input}
      assert CLI.parse_command("1 2 3\n") == {:error, :invalid_input}
    end

    test "整数ではない文字があれば失敗" do
      assert CLI.parse_command("a 1\n") == {:error, :invalid_input}
      assert CLI.parse_command("1 2b\n") == {:error, :invalid_input}
    end

    test "f のあとの座標が正しくなければ失敗" do
      assert CLI.parse_command("f\n") == {:error, :invalid_input}
      assert CLI.parse_command("f 1\n") == {:error, :invalid_input}
      assert CLI.parse_command("f a b\n") == {:error, :invalid_input}
    end

    test "空の入力は失敗" do
      assert CLI.parse_command("\n") == {:error, :invalid_input}
    end
  end

  describe "play/1" do
    # 盤面: y=0: M 1
    setup do
      %{game: Game.new(Board.from_mines(2, 1, [{0, 0}]))}
    end

    test "地雷以外を開くとクリア", %{game: game} do
      output = capture_io("1 0\n", fn -> CLI.play(game) end)

      assert output =~ "クリア"
    end

    test "地雷を開くとゲームオーバー", %{game: game} do
      output = capture_io("0 0\n", fn -> CLI.play(game) end)

      assert output =~ "ゲームオーバー"
    end

    test "間違った入力のあとも続けて遊べる", %{game: game} do
      output = capture_io("abc\n5 5\n1 0\n", fn -> CLI.play(game) end)

      assert output =~ "入力の形が正しくありません"
      assert output =~ "盤面の外です"
      assert output =~ "クリア"
    end

    test "旗を立ててから遊べる", %{game: game} do
      output = capture_io("f 0 0\n1 0\n", fn -> CLI.play(game) end)

      # 旗を立てた後の盤面: "  0  F  #"
      assert output =~ "F"
      assert output =~ "クリア"
    end

    test "盤面の外に旗は立てられない", %{game: game} do
      output = capture_io("f 5 5\nq\n", fn -> CLI.play(game) end)

      assert output =~ "盤面の外です"
    end

    test "q で終了できる", %{game: game} do
      output = capture_io("q\n", fn -> CLI.play(game) end)

      assert output =~ "終了します"
    end
  end
end
