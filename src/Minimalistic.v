Require Import FCF.FCF.
Require Import FCF.Asymptotic.
Require Import FCF.Admissibility.
Require Import Tactics.
Require Import FrapTactics.
Require Import FCF.Encryption.
Require Import FCF.SplitVector.
Require Import FCF.TwoWorldsEquiv.
Require Import FCF.OTP.
Require Import RatUtil.
Require Import RewriteUtil.
Require Import Util.
Require Import Coq.Classes.Morphisms.
Require Import Coq.Lists.SetoidList.
Require Import Coq.Lists.ListSet.
Require Import Coq.MSets.MSetPositive.
Require Import Coq.MSets.MSetProperties.
Require Import Coq.FSets.FMapPositive.
Require Import Coq.FSets.FMapFacts.
Require Import Coq.FSets.FSetFacts.
Module PositiveMapFacts := FMapFacts.WFacts_fun PositiveMap.E PositiveMap.
Module PositiveMapProperties := FMapFacts.WProperties_fun PositiveMap.E PositiveMap.
Print PositiveSet.E.
Module PositiveSetProperties := MSetProperties.WPropertiesOn PositiveSet.E MSetPositive.PositiveSet.

Section TODO.

Lemma PosMap_add_commutes : forall (x y : positive) (H : x <> y) (elt : Type) (m : PositiveMap.t elt) (A B : elt),
  PositiveMap.add x A (PositiveMap.add y B m) = PositiveMap.add y B (PositiveMap.add x A m).
Admitted.

End TODO.

Section Language.
  Context {base_type : Set}
          {interp_base_type:base_type->nat->Set}
          {eqdec_base_type : forall {t eta}, EqDec (interp_base_type t eta)}.

  Inductive type := Type_base (t:base_type) | Type_arrow (dom:type) (cod:type).
  Global Coercion Type_base : base_type >-> type.
  Fixpoint interp_type (t:type) (eta:nat) : Set :=
    match t with
    | Type_base t => interp_base_type t eta
    | Type_arrow dom cod => interp_type dom eta -> interp_type cod eta
    end.
  Delimit Scope term_scope with term.
  Bind Scope term_scope with type.
  Notation "A -> B" := (Type_arrow A B) : term_scope.

  Context {sbool message list_message rand : base_type}
          {strue sfalse:forall eta, interp_type sbool eta}.
  (* we would need a dependently typed map data structure for dependently typed randomness *)

  (* A term is parametrized by its type, which can either be one of the base_types *)
  (* listed above, or an arrow type consisting of multiple interpreted base_types. *)
  Inductive term : type -> Type :=
  | Term_const {t} (_:forall eta, interp_type t eta) : term t
  | Term_random (idx:positive) : term rand
  | Term_adversarial (_:term list_message) : term message
  | Term_app {dom cod} (_:term (Type_arrow dom cod)) (_:term dom) : term cod.
  Bind Scope term_scope with term.
  Notation "A @ B" := (Term_app A B) (at level 99) : term_scope.
  Notation "'rnd' n" := (Term_random n) (at level 35) : term_scope.
  Notation "'const' c" := (Term_const c) (at level 35) : term_scope.

  Fixpoint randomness_indices {t:type} (e:term t) : PositiveSet.t :=
    match e with
    | Term_random idx => PositiveSet.singleton idx
    | Term_app f x => PositiveSet.union (randomness_indices f) (randomness_indices x)
    | _ => PositiveSet.empty
    end.
  Global Instance randomness_map_eq_dec {eta} : EqDec (PositiveMap.t (interp_type rand eta)). Admitted.
  Context (len_rand : forall eta:nat, nat)
          (cast_rand : forall eta, Bvector (len_rand eta) -> interp_type rand eta).
  Definition generate_randomness (eta:nat) idxs
    : Comp (PositiveMap.t (interp_type rand eta))
    := PositiveSet.fold (fun i rndC => (
                             rnds' <-$ rndC;
                               ri <-$ {0,1}^(len_rand eta);
                               ret (PositiveMap.add i (cast_rand eta ri) rnds')
                           )%comp)
                        idxs
                        (ret (PositiveMap.empty _)).

  Lemma singleton_randomness : forall (eta : nat) (n : positive),
      Comp_eq (generate_randomness eta (PositiveSet.singleton n))
              (ri <-$ {0,1}^(len_rand eta);
                 ret (PositiveMap.add n (cast_rand eta ri) (PositiveMap.empty _))).
    intros.
    cbv [generate_randomness PositiveSet.singleton].
    rewrite PositiveSetProperties.fold_add.
    {
      rewrite PositiveSetProperties.fold_empty.
      rewrite Comp_eq_left_ident.
      { reflexivity. }
      { admit. }
    }
    { admit. }
    {
      cbv [Proper respectful Distribution_eq pointwise_relation RelCompFun].
      intros.
      rewrite H.
      assert (Comp_eq x0 y0).
      apply Comp_eq_evalDist.
      assumption.
      generalize a.
      apply Comp_eq_evalDist.
      setoid_rewrite H1.
      reflexivity.
    }
    {
      cbv [transpose Distribution_eq pointwise_relation RelCompFun].
      intros.
      (* TODO: Make these all tactics you can perform on Comp_eqs + ask andres about this *)
      fcf_inline_first.
      fcf_skip.
      fcf_inline_first.
      fcf_at fcf_swap fcf_left 1%nat.
      fcf_at fcf_swap fcf_right 1%nat.
      fcf_at fcf_ret fcf_left 2%nat.
      fcf_at fcf_ret fcf_right 2%nat.
      apply Comp_eq_evalDist.
      destruct (Pos.eq_dec x y).
      { rewrite e; reflexivity. }
      {
        remember (PosMap_add_commutes x y n0 (interp_type rand eta) x0) as comm.
        assert (evalDist
          (a0 <-$ { 0 , 1 }^ len_rand eta;
             a1 <-$ { 0 , 1 }^ len_rand eta;
             ret PositiveMap.add y (cast_rand eta a0) (PositiveMap.add x (cast_rand eta a1) x0)) a ==
                evalDist
          (a0 <-$ { 0 , 1 }^ len_rand eta;
             a1 <-$ { 0 , 1 }^ len_rand eta;
             ret PositiveMap.add y (cast_rand eta a1) (PositiveMap.add x (cast_rand eta a0) x0)) a).
        {
          fcf_at fcf_swap fcf_right 0%nat.
          reflexivity.
        }
        (* TODO: Do this rewrite under a bind. *)
        { admit. }
      }
    }
    { cbv [not]; apply (PositiveSetProperties.Dec.F.empty_iff n). }
  Admitted.

  Context (unreachable:forall {i}, Bvector (len_rand i)).
  Global Instance EqDec_interp_type : forall t eta, EqDec (interp_type t eta). Admitted. (* TODO: functional extensionality? *)
  Fixpoint interp_term_fixed {t} (e:term t) (eta : nat)
           (adv: interp_type list_message eta -> interp_type message eta)
           (rands: PositiveMap.t (interp_type rand eta))
    : interp_type t eta :=
    match e with
    | Term_const c => c eta
    | Term_random i => match PositiveMap.find i rands with Some r => r | _ => cast_rand eta (unreachable _) end
    | Term_adversarial ctx => adv (interp_term_fixed ctx eta adv rands)
    | Term_app f x => (interp_term_fixed f eta adv rands) (interp_term_fixed x eta adv rands)
    end.
  Definition interp_term {t} (e:term t) (eta:nat)
             (adv: interp_type list_message eta -> interp_type message eta)
    : Comp (interp_type t eta)
    := rands <-$ generate_randomness eta (randomness_indices e); ret (interp_term_fixed e eta adv rands).

  Section Security.
    (* the adversary is split into three parts for no particular reason. It first decides how much randomness it will need, then interacts with the protocol (repeated calls to [adverary] with all messages up to now as input), and then tries to claim victory ([distinguisher]). There is no explicit sharing of state between these procedures, but all of them get the same random inputs in the security game. The handling of state is a major difference between FCF [OracleComp] and this framework *)
    Definition universal_security_game 
               (evil_rand_tape_len: forall eta:nat, nat)
               (adversary:forall (eta:nat) (rand:Bvector (evil_rand_tape_len eta)), interp_type list_message eta -> interp_type message eta)
               (distinguisher: forall {t} (eta:nat) (rand:Bvector (evil_rand_tape_len eta)), interp_type t eta -> Datatypes.bool)
               (eta:nat) {t:type} (e:term t) : Comp Datatypes.bool :=
      evil_rand_tape <-$ {0,1}^(evil_rand_tape_len eta);
        out <-$ interp_term e eta (adversary eta (evil_rand_tape));
        ret (distinguisher eta evil_rand_tape out).

    Definition indist {t:type} (a b:term t) : Prop :=  forall adl adv dst,
        (* TODO: insert bounds on coputational complexity of [adv] and [dst] here *)
        let game eta e := universal_security_game adl adv dst eta e in
        negligible (fun eta => | Pr[game eta a] -  Pr[game eta b] | ).

    Global Instance Reflexive_indist {t} : Reflexive (@indist t).
    Proof.
      cbv [Reflexive indist]; setoid_rewrite ratDistance_same; eauto using negligible_0.
    Qed.

    Global Instance Symmetric_indist {t} : Symmetric (@indist t).
    Proof.
      cbv [Symmetric indist]; intros; setoid_rewrite ratDistance_comm; eauto.
    Qed.
  End Security.

  Definition whp (e:term sbool) := indist e (const strue).

  Section Equality.
    Definition const_eqb t : term (t -> t -> sbool) :=
      @Term_const
        (Type_arrow t (Type_arrow t (Type_base sbool)))
        (fun eta x1 x2 => if eqb x1 x2 then strue eta else sfalse eta).
    Definition eqwhp {t:type} (e1 e2:term t) : Prop := whp (const_eqb t @ e1 @ e2)%term.

    Global Instance Reflexive_eqwhp {t} : Reflexive (@eqwhp t).
    Proof.
      cbv [Reflexive indist universal_security_game eqwhp whp interp_term]; intros.
      apply eq_impl_negligible; intro eta.
      eapply Proper_Bind; [reflexivity|]; intros ? ? ?; subst.
      eapply Proper_Bind; [|intros ? ? ?; subst; reflexivity]. 
      simpl interp_term_fixed.
      etransitivity.
      { eapply Proper_Bind; [reflexivity|]; intros ? ? ?; subst.
        (* TODO: why can't we do this earlier (under binders) using setoid_rewrite? *)
        rewrite eqb_refl.
        instantiate (1:=fun _ => ret strue eta); cbv beta.
        reflexivity. }
      rewrite 2Bind_unused.
      reflexivity.
    Qed.
  End Equality.

  Section LateInterp.
    Fixpoint interp_term_late
             {t} (e:term t) (eta : nat)
             (adv: interp_type list_message eta -> interp_type message eta)
             (fixed_rand: PositiveMap.t (interp_type rand eta))
    : Comp (interp_type t eta) :=
      match e with
      | Term_const c => ret (c eta)
      | Term_random i =>
        match PositiveMap.find i fixed_rand with
        | Some r => ret r
        | _ => r <-$ {0,1}^(len_rand eta); ret (cast_rand eta r)
        end
      | Term_adversarial ctx =>
        ctx <-$ interp_term_late ctx eta adv fixed_rand; ret (adv ctx)
      | Term_app f x => 
        common_rand <-$ generate_randomness eta (PositiveSet.inter (randomness_indices x) (randomness_indices f));
          let rands := PositiveMapProperties.update common_rand fixed_rand in
          x <-$ interp_term_late x eta adv rands;
          f <-$ interp_term_late f eta adv rands;
          ret (f x)
      end.

    Lemma interp_term_late_correct' {t} (e:term t) eta :
      forall adv univ (H:PositiveSet.Subset (randomness_indices e) univ) fixed,
      Comp_eq (interp_term_late e eta adv fixed)
              (rands <-$ generate_randomness eta univ;
                 ret (interp_term_fixed e eta adv (PositiveMapProperties.update rands fixed))).
    Proof.
      induction e; intros;
        simpl interp_term_late; simpl interp_term_fixed.
      { rewrite Bind_unused. reflexivity. }
      { admit. }
      { admit. }
      { 
    Admitted.
    Lemma interp_term_late_correct {t} (e:term t) eta adv :
      Comp_eq (interp_term_late e eta adv (PositiveMap.empty _))
              (interp_term e eta adv).
      induction e; intros. admit. admit. admit.
      simpl.
      cbv [interp_term].
      simpl.
      eapply Proper_Bind.
      (* this form is not strong enough for induction? *)
    Admitted.
  End LateInterp.

  Fixpoint fresh r {t} (e: term t) : Prop :=
    match e with
    | Term_random idx => idx = r
    | Term_app func arg => fresh r func /\ fresh r arg
    | _ => True
    end.
  (* interp term of (rand to T) of term rand *)

  Section OTP.
    Definition T' := interp_type message.
    Hypothesis T'_EqDec : forall (eta : nat), EqDec (T' eta).
    Variable RndT'_symbolic : forall (eta : nat), interp_type (rand -> message) eta. 
    Definition RndT' := fun (eta : nat) => x <-$ {0,1}^(len_rand eta);
                                        ret (RndT'_symbolic eta (cast_rand eta x)).
    Variable T_op' : forall (eta : nat), interp_type (message -> message -> message)%term eta.
    Hypothesis op_assoc' : forall (eta : nat), forall x y z, T_op' eta (T_op' eta x y) z = T_op' eta x (T_op' eta y z).
    Variable T_inverse' : forall (eta : nat), interp_type(message -> message)%term eta. 
    Variable T_ident' : forall (eta : nat), T' eta.
    Hypothesis inverse_l_ident' : forall (eta : nat), forall x, T_op' eta (T_inverse' eta x) x = T_ident' eta.
    Hypothesis inverse_r_ident' : forall (eta : nat), forall x, T_op' eta x (T_inverse' eta x) = T_ident' eta.
    Hypothesis ident_l : forall (eta : nat), forall x, (T_op' eta) (T_ident' eta) x = x.
    Hypothesis ident_r : forall (eta : nat), forall x, (T_op' eta) x (T_ident' eta) = x.
    Hypothesis RndT_uniform : forall (eta : nat), forall x y, comp_spec (fun a b => a = x <-> b = y) (RndT' eta) (RndT' eta).

    Let comp_spec_otp_l eta
      : forall (x : T' eta), comp_spec eq (RndT' eta) (r <-$ RndT' eta; ret T_op' eta x r)
      := @OTP_inf_th_sec_l (T' eta) _ (RndT' eta) (T_op' eta) (op_assoc' eta) (T_inverse' eta) (T_ident' eta) (inverse_l_ident' eta) (inverse_r_ident' eta) (ident_l eta) (RndT_uniform eta).

    (* forall x y, A x y ==> B (f x) (f y) *)
    (* Proper PositiveSetEq CompEq generate_randomness *)

    (* Definition weird_eq := fun (A : Set) (c1 c2 : Comp A) => Comp_eq c1 c2. *)
    Global Instance Proper_PosSetEq (eta : nat) :
      Proper (PositiveSet.Equal ==> Comp_eq) (generate_randomness eta).
    Admitted.

    Theorem symbolic_OTP : forall (n : positive) (x : forall (eta : nat), T' eta), indist (const RndT'_symbolic @ (rnd n)) (const T_op' @ const x @ (const RndT'_symbolic @ (rnd n)))%term.
    Proof.
      cbv [indist universal_security_game]; intros.
      apply eq_impl_negligible; cbv [pointwise_relation]; intros eta.
      specialize (comp_spec_otp_l eta (x eta)).
      apply Comp_eq_evalDist.
      intros.
      fcf_skip.
      cbv [RndT'] in H.
      cbv [interp_term interp_term_fixed randomness_indices].
      assert (evalDist
                (out <-$
                     (rands <-$
                            generate_randomness eta (PositiveSet.singleton n);
                      ret RndT'_symbolic eta
                          match PositiveMap.find n rands with
                          | Some r => r
                          | None => cast_rand eta (unreachable eta)
                          end); ret dst message eta x0 out) c ==
              evalDist
                (out <-$
                     (rands <-$
                            generate_randomness eta (PositiveSet.singleton n);
                      ret T_op' eta (x eta)
                          (RndT'_symbolic eta
                                          match PositiveMap.find n rands with
                                          | Some r => r
                                          | None => cast_rand eta (unreachable eta)
                                          end)); ret dst message eta x0 out) c).
      {
        fcf_inline_first.
        apply Comp_eq_evalDist.
        setoid_rewrite singleton_randomness.
        setoid_rewrite <-Comp_eq_associativity.
        apply Comp_eq_evalDist.
        intros.
        fcf_at fcf_ret fcf_left 1%nat.
        fcf_at fcf_ret fcf_right 1%nat.
        apply Comp_eq_evalDist.

        (* WHY does setoid_rewrite not work here? For now, inline the rewriting... *)
        (* etransitivity. *)
        (* eapply Proper_Bind. reflexivity. cbv [respectful]. intros. subst. *)
        (* setoid_rewrite PositiveMapProperties.F.add_eq_o; [|reflexivity]. *)
        (* match goal with |- ?R ?LHS ?RHS => *)
        (*                 match (eval pattern y in LHS) with *)
        (*                   ?LHS' _ => eapply (reflexivity (LHS' y)) *)
        (*                 end *)
        (* end. *)

        (* etransitivity. Focus 2. { *)
        (* eapply Proper_Bind. reflexivity. cbv [respectful]. intros. subst. symmetry. *)
        (* setoid_rewrite PositiveMapProperties.F.add_eq_o; [|reflexivity]. *)
        (* match goal with |- ?R ?LHS ?RHS => *)
        (*                 match (eval pattern y in LHS) with *)
        (*                   ?LHS' _ => eapply (reflexivity (LHS' y)) *)
        (*                 end *)
        (* end. } Unfocus. *)
        assert(Comp_eq
              (a <-$ { 0 , 1 }^ len_rand eta;
               ret dst message eta x0
                   (RndT'_symbolic eta
                                   match Some (cast_rand eta a)
                                   with
                                   | Some r => r
                                   | None => cast_rand eta (unreachable eta)
                                   end))
              (a <-$ { 0 , 1 }^ len_rand eta;
               ret dst message eta x0
                   (T_op' eta (x eta)
                          (RndT'_symbolic eta
                                          match Some (cast_rand eta a)
                                          with
                                          | Some r => r
                                          | None => cast_rand eta (unreachable eta)
                                          end)))).
        cbv [RndT'] in comp_spec_otp_l.
        etransitivity.
        {
          etransitivity.
          {
            instantiate (1:= a <-$ { 0 , 1 }^ len_rand eta;
                             b <-$ ret RndT'_symbolic eta (cast_rand eta a);
                             ret dst message eta x0 b).
            apply Comp_eq_evalDist.
            intros.
            fcf_at fcf_ret fcf_right 1%nat.
            reflexivity.
          }
          {
            instantiate (1:= r <-$ (x <-$ { 0 , 1 }^ len_rand eta; ret RndT'_symbolic eta (cast_rand eta x));
                             b <-$ ret T_op' eta (x eta) r;
                             ret dst message eta x0 b).
            assert (Comp_eq (a <-$ { 0 , 1 }^ len_rand eta;
                             ret RndT'_symbolic eta (cast_rand eta a))
                            (r <-$ (x1 <-$ { 0 , 1 }^ len_rand eta; ret RndT'_symbolic eta (cast_rand eta x1));
                             ret T_op' eta (x eta) r)).
            { apply comp_spec_impl_Comp_eq in comp_spec_otp_l; assumption. }
            {
              rewrite Comp_eq_associativity.
              {
                rewrite Comp_eq_associativity.
                {
                  eapply Proper_Bind.
                  { assumption. }
                  { cbv [respectful]; intros; rewrite H1; reflexivity. }
                }
                { admit. }
              }
              { admit. }
            }
          }
        }
        {
          rewrite <-Comp_eq_associativity.
          apply Comp_eq_evalDist.










      (* If the first part of the bind is Comp_eq and the second part is the same, the whole thing is Comp_eq. *)
      (* assert (Comp_eq *)
      (*           (ret dst message eta x0 *)
      (*                (RndT'_symbolic eta *)
      (*                                match PositiveMap.find n x1 with *)
      (*                                | Some r => r *)
      (*                                | None => cast_rand eta (unreachable eta) *)
      (*                                end)) *)
      (*           (out <-$ *)
      (*                ret T_op' eta (x eta) *)
      (*                (RndT'_symbolic eta *)
      (*                                match PositiveMap.find n x1 with *)
      (*                                | Some r => r *)
      (*                                | None => cast_rand eta (unreachable eta) *)
      (*                                end); ret dst message eta x0 out) *)



      (* pull out randomness and then casting and then symbolicizing it is the same as *)
      (* pull out randomnes, cast, symbolicize, call top on it and x *)
    Admitted.

  End OTP.

  Lemma indist_rand (x y:positive) : indist (rnd x) (rnd y).
  Proof.
    cbv [indist]; intros.
    apply eq_impl_negligible; cbv [pointwise_relation]; intros eta.
    cbv [universal_security_game].
    (* setoid_rewrite <-interp_term_late_correct. WHY does it not work? *)
    eapply Proper_Bind; [reflexivity|]; intros ? ? ?; subst.
    setoid_rewrite <-interp_term_late_correct.
    simpl interp_term_late.
    rewrite 2PositiveMap.gempty.
    reflexivity.
  Qed.
End Language.
Arguments type _ : clear implicits.