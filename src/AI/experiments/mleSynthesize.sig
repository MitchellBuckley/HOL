signature mleSynthesize =
sig

  include Abbrev

  type board = term * term * int
  type move = term

  (* target *)
  val create_targetl : term list -> board list
  val export_targetl : board list -> unit
  val import_targetd : unit -> (board, int * bool list) Redblackmap.dict

  (* reinforcement learning *)
  val extsearch : board mlReinforce.es
  val rlobj : (board,move) mlReinforce.rlobj

  (* transformation to goals for TPTP export *)
  val goal_of_board_eq : board -> goal
  val goal_of_board_rw : board -> goal
  val goal_of_board_ev : board -> goal

end
