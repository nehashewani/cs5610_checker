defmodule CheckerWeb.CheckerGame do
  use GenServer
  # Attribution: http://codeloveandboards.com/blog/2016/05/21/building-phoenix-battleship-pt-3/
  # We learn how this attribution arrange the code structure.

  # idiot formatter!!
  defstruct id: nil,
            red: nil,
            black: nil,
            viewers: [],
            turn: "r",
            borard_state: [
              "b",
              "b",
              "b",
              "b",
              "b",
              "b",
              "b",
              "b",
              "b",
              "b",
              "b",
              "b",
              "",
              "",
              "",
              "",
              "",
              "",
              "",
              "",
              "r",
              "r",
              "r",
              "r",
              "r",
              "r",
              "r",
              "r",
              "r",
              "r",
              "r",
              "r"
            ]

  # pid is the channel pid which should be monitored.
  def join(id, player_id, pid), do: try_call(id, {:join, player_id, pid})

  def resign_game(game_id, user_id) do
    server = ref(game_id)
    Elixir.GenServer.stop(server)
    # send broadcast to all connect to game:id
    send_broadcast_game_result(game_id, user_id)
  end

  # userid will be int
  # assume step like [0, 2]
  # return the game_state: whole dict
  def check_validation(user_id, game_id, step) do
    # check all rules.
    user_id = Integer.to_string(user_id)
    game = get_data(game_id)
    from = step["from"]
    to = step["to"]

    cond do
      user_id != game.red and user_id != game.black ->
        {:error, "Not valid user for this game."}

      user_id == game.red and game.turn == "b" ->
        {:error, "Not your turn."}

      user_id == game.black and game.turn == "r" ->
        {:error, "Not your turn."}

      true ->
        # It's user's turn check the step
        # Try to check the value: position, eat piece, become queen
        moves = move_positions(from, game.board_state)
        jumps = jump_positions(from, game.board_state)

        cond do
          check_occupied(to) ->
            {:error, "Invalid step."}

          # below have prerequisite: the to_pos is empty
          # it's a move
          to in moves ->
            game = become_queue(to, game)
            # handle update
            try_call(game.id, {:update, game})
            {:ok, game}

          # it's a jump
          # end_game_check only after jump
          to in jumps ->
            game = become_queue(to, game)
            # handle update
            try_call(game.id, {:update, game})

            # if find game is end, open a new process to broadcast(wait a second)
            # when channel recive state, check whether a winner at first
            # then may send a win message to server, server will check
            spawn(__MODULE__, :check_win, [game])
            {:ok, game}
        end
    end
  end

  # if it has winner, send broadcast, end GenServer
  def check_win(game) do
    # must wait a short time to make sure client has updated their view.
  end

  # (consider about non-empty)
  def check_occupied(to) do
  end

  # game is a dict
  # make the real position change by pos(to) here
  def become_queen(pos, game) do
    # if pos can be a queen, then return a new game
  end

  # pos: int 0-31, board: list of 32 board unit
  def move_positions(pos, board) do
    # return list of all valid move position
    # Enum.at([], 1) -> xx
  end

  # pos: int 0-31, board: list of 32 board unit
  def jump_positions(pos, board) do
    # return list of all valid jump
    # notice: can still jump after a jump!
  end

  def get_data(game_id), do: try_call(game_id, :get_data)

  def start_link(id) do
    GenServer.start_link(__MODULE__, id, name: ref(id))
  end

  def ref(id), do: {:global, {:game, id}}

  def init(id) do
    {:ok, %__MODULE__{id: id}}
  end

  # not need to use ref before this function
  def try_call(id, message) do
    case GenServer.whereis(ref(id)) do
      nil ->
        {:error, "Game does not exist"}

      game ->
        GenServer.call(game, message)
    end
  end

  def send_broadcast_game_with_winner(game_id, winner_id) do
  end

  def send_broadcast_game_result(game_id, loser_id) do
    CheckerWeb.Endpoint.broadcast("game:" <> game_id, "game_result", %{"loser" => loser_id})
  end

  def send_braodcast_update_user_info(game) do
    game_id = game.id
    CheckerWeb.Endpoint.broadcast("game:" <> game_id, "update_user_info", %{"game" => game})
  end

  defp add_player(%__MODULE__{red: nil} = game, user_id) do
    new_game = %{game | red: user_id}
    send_braodcast_update_user_info(new_game)
    new_game
  end

  defp add_player(%__MODULE__{black: nil} = game, user_id) do
    new_game = %{game | black: user_id}
    send_braodcast_update_user_info(new_game)
    new_game
  end

  defp add_player(game, user_id) do
    new_game = %{game | viewers: [user_id | game.viewers]}
    send_braodcast_update_user_info(new_game)
    new_game
  end

  # change turn, update board
  def handle_call({:update, new_game}, _from, game) do
  end

  # pid is channel's pid
  def handle_call({:join, user_id, pid}, _from, game) do
    cond do
      Enum.member?([game.red, game.black], user_id) ->
        {:reply, {:ok, self}, game}

      Enum.member?(game.viewers, user_id) ->
        {:reply, {:ok, self}, game}

      true ->
        Process.flag(:trap_exit, true)
        Process.monitor(pid)

        game = add_player(game, user_id)

        {:reply, {:ok, self}, game}
    end
  end

  def handle_call(:get_data, _from, game), do: {:reply, game, game}
end
