structure computeLib :> computeLib =
struct

open HolKernel boolSyntax boolTheory Abbrev clauses compute_rules equations;

val auto_import_definitions = ref true;

(* re-exporting types from clauses *)

type compset = comp_rws;

val new_compset = from_list;

type cbv_stack =
  ((thm->thm->thm) * (thm * db fterm),
   (thm->thm->thm) * bool * (thm * db fterm),
   (thm->thm)) stack;

fun stack_out(th, Ztop) = th
  | stack_out(th, Zrator{Rand=(mka,(thb,_)), Ctx}) = stack_out(mka th thb,Ctx)
  | stack_out(th,Zrand{Rator=(mka,_,(tha,_)),Ctx}) = stack_out(mka tha th, Ctx)
  | stack_out(th, Zabs{Bvar=mkl, Ctx})             = stack_out (mkl th, Ctx)
;


fun initial_state rws t =
  ((refl_thm t, mk_clos([],from_term (rws,[],t))), Ztop : cbv_stack);


(*---------------------------------------------------------------------------
 * [cbv_wk (rws,(th,cl),stk)] puts the closure cl (useful information about
 * the rhs of th) in head normal form (weak reduction). It returns either
 * a closure which term is an abstraction, in a context other than Zappl,
 * a variable applied to strongly reduced arguments, or a constant
 * applied to weakly reduced arguments which does not match any rewriting
 * rule.
 *
 * - substitution is propagated through applications.
 * - if the rhs is an abstraction and there is one arg on the stack,
 *   this means we found a beta redex. mka rebuilds the application of
 *   the function to its argument, and Beta does the actual beta step.
 * - for an applied constant, we look for a rewrite matching it.
 *   If we found one, then we apply the instantiated rule, and go on.
 *   Otherwise, we try to rebuild the thm.
 * - for an already strongly normalized term or an unapplied abstraction,
 *   we try to rebuild the thm.
 *---------------------------------------------------------------------------*)

fun cbv_wk ((th,CLOS{Env, Term=App(a,args)}), stk) =
      let val (tha,stka) =
            foldl (push_in_stk (curry mk_clos Env)) (th,stk) args in
      cbv_wk ((tha, mk_clos(Env,a)), stka)
      end
  | cbv_wk ((th,CLOS{Env, Term=Abs body}),
	    Zrator{Rand=(mka,(thb,cl)), Ctx=s'}) =
      cbv_wk ((beta_thm(mka th thb), mk_clos(cl :: Env, body)), s')
  | cbv_wk ((th,CST cargs), stk) =
      let val (reduced,clos) = reduce_cst (th,cargs) in
      if reduced then cbv_wk (clos,stk) else cbv_up (clos,stk)
      end
  | cbv_wk (clos, stk) = cbv_up (clos,stk)


(*---------------------------------------------------------------------------
 * Tries to rebuild the thm, knowing that the closure has been weakly
 * normalized, until it finds term still to reduce, or if a strong reduction
 * may be required.
 *  - if we are done with a Rator, we start reducing the Rand
 *  - if we are done with the Rand of a const, we rebuild the application
 *    and look if it created a redex
 *  - an application to a NEUTR can be rebuilt only if the argument has been
 *    strongly reduced, which we now for sure only if itself is a NEUTR.
 *---------------------------------------------------------------------------*)

and cbv_up (hcl, Zrator{Rand=(mka,clos), Ctx})  =
      let val new_state = (clos, Zrand{Rator=(mka,false,hcl), Ctx=Ctx}) in
      if is_skip hcl then cbv_up new_state else cbv_wk new_state
      end
  | cbv_up ((thb,v), Zrand{Rator=(mka,false,(th,CST cargs)), Ctx=stk}) =
      cbv_wk ((mka th thb, comb_ct cargs (rhs_concl thb, v)), stk)
  | cbv_up ((thb,NEUTR), Zrand{Rator=(mka,false,(th,NEUTR)), Ctx=stk}) =
      cbv_up ((mka th thb, NEUTR), stk)
  | cbv_up (clos, stk) = (clos,stk)
;

(*---------------------------------------------------------------------------
 * [strong] continues the reduction of a term in head normal form under
 * abstractions, and in the arguments of non reduced constant.
 * precondition: the closure should be the output of cbv_wk
 *---------------------------------------------------------------------------*)

fun strong ((th, CLOS{Env,Term=Abs t}), stk) =
      let val (thb,stk') = push_lam_in_stk(th,stk) in
      strong (cbv_wk((thb, mk_clos(NEUTR :: Env, t)), stk'))
      end
  | strong (clos as (_,CLOS _), stk) = raise DEAD_CODE "strong"
  | strong (hcl as (th,CST {Args,...}), stk) =
      let val (th',stk') =
 	if is_skip hcl then (th,stk)
 	else foldl (push_in_stk snd) (th,stk) Args in
      strong_up (th',stk')
      end
  | strong ((th, NEUTR), stk) = strong_up (th,stk)

and strong_up (th, Ztop) = th
  | strong_up (th, Zrand{Rator=(mka,false,(tha,NEUTR)), Ctx}) =
      strong (cbv_wk((mka tha th,NEUTR), Ctx))
  | strong_up (th, Zrand{Rator=(mka,false,clos), Ctx}) =
      raise DEAD_CODE "strong_up"
  | strong_up (th, Zrator{Rand=(mka,clos), Ctx}) =
      strong (cbv_wk(clos, Zrand{Rator=(mka,true,(th,NEUTR)), Ctx=Ctx}))
  | strong_up (th, Zrand{Rator=(mka,true,(tha,_)), Ctx}) =
      strong_up (mka tha th, Ctx)
  | strong_up (th, Zabs{Bvar=mkl, Ctx}) = strong_up (mkl th, Ctx)
;


(*---------------------------------------------------------------------------
 * [CBV_CONV rws t] is a conversion that does the full normalization of t,
 * using rewrites rws.
 *---------------------------------------------------------------------------*)

fun CBV_CONV rws = evaluate o strong o cbv_wk o initial_state rws;

(*---------------------------------------------------------------------------
 * WEAK_CBV_CONV is the same as CBV_CONV except that it does not reduce
 * under abstractions, and reduce weakly the arguments of constants.
 * Reduction whenever we reach a state where a strong reduction is needed.
 *---------------------------------------------------------------------------*)

fun WEAK_CBV_CONV rws =
      evaluate
    o (fn ((th,_),stk) => stack_out(th,stk))
    o cbv_wk
    o initial_state rws;

(*---------------------------------------------------------------------------
 * Adding an arbitrary conv
 *---------------------------------------------------------------------------*)

fun extern_of_conv rws conv tm =
  let val thm = conv tm in
  (thm, mk_clos([],from_term(rws,[],rhs(concl thm))))
  end;

fun add_conv (cst,arity,conv) rws =
  add_extern (cst,arity,extern_of_conv rws conv) rws;

fun set_skip compset c opt =
 let val {Name,Thy,...} = dest_thy_const c
 in clauses.set_skip compset (Name,Thy) opt
 end
 handle HOL_ERR _ => raise ERR "set_skip" "";

(*---------------------------------------------------------------------------
       Support for a global compset.
 ---------------------------------------------------------------------------*)

val bool_redns =
 strictify_thm LET_DEF
 :: List.map lazyfy_thm
      [COND_CLAUSES, COND_ID, NOT_CLAUSES, bool_case_thm,
       AND_CLAUSES, OR_CLAUSES, IMP_CLAUSES, EQ_CLAUSES];

fun bool_compset() = from_list bool_redns;

val the_compset = bool_compset();

val add_funs = Lib.C add_thms the_compset;
val add_convs = List.app (Lib.C add_conv the_compset);

val EVAL_CONV = CBV_CONV the_compset;
val EVAL_RULE = Conv.CONV_RULE EVAL_CONV;
val EVAL_TAC = Tactic.CONV_TAC EVAL_CONV;

infix Orelse;
fun (p Orelse q) x = p x orelse q x;

fun OR [] = K false
  | OR [x] = same_const x
  | OR (h::t) = same_const h Orelse OR t;

fun RESTR_EVAL_CONV clist =
  Lib.with_flag (stoppers,SOME (OR clist)) EVAL_CONV;

val RESTR_EVAL_TAC  = Tactic.CONV_TAC o RESTR_EVAL_CONV;
val RESTR_EVAL_RULE = Conv.CONV_RULE o RESTR_EVAL_CONV;

(*---------------------------------------------------------------------------
      Support for persistence of the_compset
 ---------------------------------------------------------------------------*)

fun write_datatype_info tyinfo =
 let open TypeBasePure Drule
     val size_opt =
       case size_of0 tyinfo
        of SOME (_, ORIG def) => SOME def
         | otherwise => NONE
     val boolify_opt =
       case boolify_of0 tyinfo
        of SOME (_, ORIG def) => SOME def
         | otherwise => NONE
     val compset_addns = [size_opt, boolify_opt]
     val simpls = #rewrs (simpls_of tyinfo)
 in
    add_funs (mapfilter Option.valOf compset_addns @ simpls)
 end

fun add_persistent_funs [] = ()
  | add_persistent_funs alist =
    let open Portable
        val (names,thms) = unzip alist
    in
       add_funs thms
     ; Theory.adjoin_to_theory
         {sig_ps = NONE,
          struct_ps = SOME(fn ppstrm =>
             (PP.begin_block ppstrm CONSISTENT 0;
              PP.add_string ppstrm "val _ = computeLib.add_funs [";
              PP.begin_block ppstrm INCONSISTENT 0;
              pr_list_to_ppstream ppstrm
                 PP.add_string (C PP.add_string ",")
                 (C PP.add_break (0,0)) names;
              PP.end_block ppstrm;
              PP.add_string ppstrm "];";
              PP.add_break ppstrm (2,0);
              PP.end_block ppstrm))}
    end

end
