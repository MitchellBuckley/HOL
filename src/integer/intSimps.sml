structure intSimps :> intSimps =
struct

open HolKernel boolLib integerTheory intSyntax simpLib

val ERR = mk_HOL_ERR "intSimps";

(*---------------------------------------------------------------------------*)
(* Integer-specific compset                                                  *)
(*---------------------------------------------------------------------------*)

val elim_thms = [INT_ADD_REDUCE, INT_SUB_REDUCE, INT_MUL_REDUCE,
                 INT_DIV_REDUCE, INT_MOD_REDUCE, INT_EXP_REDUCE,
                 INT_LT_REDUCE, INT_LE_REDUCE, INT_EQ_REDUCE,
                 INT_GT_REDUCE, INT_GE_REDUCE, INT_DIVIDES_REDUCE,
                 INT_ABS_NUM, INT_ABS_NEG, INT_QUOT_REDUCE, INT_REM_REDUCE,
                 INT_MAX, INT_MIN]

fun int_compset () =
 let open computeLib
     val compset = reduceLib.num_compset()
     val _ = add_thms elim_thms compset
 in
  compset
 end;

(*---------------------------------------------------------------------------*)
(* Reducer for ground integer expressions                                    *)
(*---------------------------------------------------------------------------*)

val REDUCE_CONV = computeLib.CBV_CONV (int_compset())

(*---------------------------------------------------------------------------*)
(* Add integer reductions to the global compset                              *)
(*---------------------------------------------------------------------------*)

val _ = let open computeLib in add_funs elim_thms end;

(*---------------------------------------------------------------------------*)
(* Ground reduction conversions for integers (suitable for inclusion in      *)
(* simplifier, or as stand-alone                                             *)
(*---------------------------------------------------------------------------*)

local
  val num_ty = numSyntax.num
  val int_ty = intSyntax.int_ty
  val x = mk_var("x",int_ty)
  val y = mk_var("y",int_ty)
  val n = mk_var("n",num_ty)
  val basic_op_terms =
     [plus_tm, minus_tm, mult_tm, div_tm, mod_tm, int_eq_tm,
      less_tm, leq_tm, great_tm, geq_tm, divides_tm, rem_tm, quot_tm,
      min_tm, max_tm]
  val basic_op_patterns = map (fn t => list_mk_comb(t, [x,y])) basic_op_terms
  val exp_pattern = list_mk_comb(exp_tm, [x,n])
  val abs_patterns = [lhs (#2 (strip_forall (concl INT_ABS_NEG))),
                      lhs (#2 (strip_forall (concl INT_ABS_NUM)))]
  fun reducible t = is_int_literal t orelse numSyntax.is_numeral t
  fun reducer t =
    let val (_, args) = strip_comb t
    in if List.all reducible args then REDUCE_CONV t else Conv.NO_CONV t
    end
  fun mk_conv pat =
     {name = "Integer calculation",
      key = SOME([], pat), trace = 2,
      conv = K (K reducer)}
  val rederr = ERR "RED_CONV" "Term not reducible"
in
val INT_REDUCE_ss = SIMPSET
  {convs = map mk_conv (exp_pattern::(abs_patterns @ basic_op_patterns)),
   rewrs = [], congs = [], filter = NONE, ac = [], dprocs = []};

fun RED_CONV t =
 let val (f, args) = strip_comb t
     val _ = f = exp_tm orelse mem f basic_op_terms orelse raise rederr
     val _ = List.all reducible args orelse raise rederr
     val _ = not (Lib.can dom_rng (type_of t)) orelse raise rederr
 in
   REDUCE_CONV t
 end

end (* local *) ;

(*---------------------------------------------------------------------------*)
(* Add reducer to srw_ss                                                     *)
(*---------------------------------------------------------------------------*)

val _ = BasicProvers.augment_srw_ss [INT_REDUCE_ss];

(*---------------------------------------------------------------------------*)
(* Accumulate literal additions in integer expressions                       *)
(*---------------------------------------------------------------------------*)

fun collect_additive_consts tm = let
  val summands = strip_plus tm
in
  case summands of
    [] => raise Fail "strip_plus returned [] in collect_additive_consts"
  | [_] => NO_CONV tm
  | _ => let
    in
      case partition is_int_literal summands of
        ([], _) => NO_CONV tm
      | ([_], _) => NO_CONV tm
      | (_, []) => REDUCE_CONV tm
      | (numerals, non_numerals) => let
          val reorder_t = mk_eq(tm,
                           mk_plus(list_mk_plus non_numerals,
                                   list_mk_plus numerals))
          val reorder_thm =
            EQT_ELIM(AC_CONV(INT_ADD_ASSOC, INT_ADD_COMM) reorder_t)
        in
          (K reorder_thm THENC REDUCE_CONV THENC
           TRY_CONV (REWR_CONV INT_ADD_RID)) tm
        end
    end
end

(*---------------------------------------------------------------------------*)
(* Support for ordered AC rewriting                                          *)
(*---------------------------------------------------------------------------*)

val INT_ADD_AC_ss = ac_ss [(INT_ADD_ASSOC,INT_ADD_COMM)]
val INT_MUL_AC_ss = ac_ss [(INT_MUL_ASSOC,INT_MUL_COMM)]
val INT_AC_ss = merge_ss [INT_ADD_AC_ss,INT_MUL_AC_ss]


(*---------------------------------------------------------------------------*)
(* Standard simplifications for the integers. Does not use the integer       *)
(* decision procedure.                                                       *)
(*---------------------------------------------------------------------------*)

val INT_RWTS_ss = integerTheory.integer_rwts;

val int_ss =
  boolSimps.bool_ss ++ pairSimps.PAIR_ss ++ optionSimps.OPTION_ss ++
  sumSimps.SUM_ss ++ combinSimps.COMBIN_ss ++
  numSimps.REDUCE_ss ++ numSimps.ARITH_ss ++ INT_REDUCE_ss ++
  INT_RWTS_ss;

(* Formerly the following underpowered version was used:
  val int_ss = boolSimps.bool_ss ++ INT_REDUCE_ss;
*)

end
