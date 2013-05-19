(** This file is part of CoqEAL, the Coq Effective Algebra Library.
(c) Copyright INRIA and University of Gothenburg. *)
Require Import ZArith Ncring Ncring_tac.
Require Import ssreflect ssrbool ssrfun eqtype ssrnat seq choice fintype.
Require Import div finfun bigop prime binomial ssralg finset fingroup finalg.
Require Import perm zmodp matrix refinements seqmatrix.

Instance Zops (R : ringType) (n : nat) : @Ring_ops 'M[R]_n 0%R
  (scalar_mx 1) (@addmx R _ _) mulmx (fun M N => addmx M (oppmx N)) (@oppmx R _ _) eq.

Instance Zr (R : ringType) (n : nat) : (@Ring _ _ _ _ _ _ _ _ (Zops R n)).
Proof.
constructor=> //.
  + exact:eq_equivalence.
  + by move=> x y H1 u v H2; rewrite H1 H2.
  + by move=> x y H1 u v H2; rewrite H1 H2.
  + by move=> x y H1 u v H2; rewrite H1 H2.
  + by move=> x y H1; rewrite H1.
  + exact:add0mx.
  + exact:addmxC.
  + exact:addmxA.
  + exact:mul1mx.
  + exact:mulmx1.
  + exact:mulmxA.
  + exact:mulmxDl.
  + by move=> M N P ; exact:mulmxDr.
  + by move=> M; rewrite /addition /add_notation (addmxC M) addNmx.
Qed.

Section Strassen_generic.

Local Open Scope ring_scope.

(** K is the size threshold below which we switch back to naive
multiplication *)
Let K := 32%positive.

Local Coercion nat_of_pos : positive >-> nat.

Lemma addpp p : xO p = (p + p)%N :> nat.
Proof. by rewrite /= NatTrec.trecE addnn. Qed.

Lemma addSpp p : xI p = (p + p).+1%N :> nat.
Proof. by rewrite /= NatTrec.trecE addnn. Qed.

Lemma addp1 p : xI p = (xO p + 1)%N :> nat.
Proof. by rewrite addn1. Qed.

Lemma addpp1 p : xI p = (p + p + 1)%N :> nat.
Proof. by rewrite /= NatTrec.trecE addnn addn1. Qed.

Lemma lt0p : forall p : positive, 0 < p.
Proof.
by elim=> // p IHp /=; rewrite NatTrec.doubleE -addnn; exact:ltn_addl.
Qed.

Import Refinements.Op.

Variable mxA : nat -> nat -> Type.

Context `{!hadd mxA, !hsub mxA, !hmul mxA, !hcast mxA}.
Context `{!ulsub mxA, !ursub mxA, !dlsub mxA, !drsub mxA, !block mxA}.

Definition Strassen_step {p : positive} (A B : mxA (p + p) (p + p))
  (f : mxA p p -> mxA p p -> mxA p p) : mxA (p + p) (p + p) :=
  let A11 := ulsub_op A in
  let A12 := ursub_op A in
  let A21 := dlsub_op A in
  let A22 := drsub_op A in
  let B11 := ulsub_op B in
  let B12 := ursub_op B in
  let B21 := dlsub_op B in
  let B22 := drsub_op B in
  let X := hsub_op A11 A21 in
  let Y := hsub_op B22 B12 in
  let C21 := f X Y in
  let X := hadd_op A21 A22 in
  let Y := hsub_op B12 B11 in
  let C22 := f X Y in
  let X := hsub_op X A11 in
  let Y := hsub_op B22 Y in
  let C12 := f X Y in
  let X := hsub_op A12 X in
  let C11 := f X B22 in
  let X := f A11 B11 in
  let C12 := hadd_op X C12 in
  let C21 := hadd_op C12 C21 in
  let C12 := hadd_op C12 C22 in
  let C22 := hadd_op C21 C22 in
  let C12 := hadd_op C12 C11 in
  let Y := hsub_op Y B21 in
  let C11 := f A22 Y in
  let C21 := hsub_op C21 C11 in
  let C11 := f A12 B21 in
  let C11 := hadd_op X C11 in
  block_op C11 C12 C21 C22.

Definition Strassen_xO {p : positive} Strassen_p :=
  fun A B =>
    if p <= K then hmul_op A B else
    let A := hcast_op (addpp p,addpp p) A in
    let B := hcast_op (addpp p,addpp p) B in
    hcast_op (esym (addpp p), esym (addpp p)) (Strassen_step A B Strassen_p).
  
Definition Strassen_xI {p : positive} Strassen_p :=
   fun M N =>
    if p <= K then hmul_op M N else
    let M := hcast_op (addpp1 p, addpp1 p) M in
    let N := hcast_op (addpp1 p, addpp1 p) N in
    let M11 := ulsub_op M in
    let M12 := ursub_op M in
    let M21 := dlsub_op M in
    let M22 := drsub_op M in
    let N11 := ulsub_op N in
    let N12 := ursub_op N in
    let N21 := dlsub_op N in
    let N22 := drsub_op N in
    let C := hadd_op (Strassen_step M11 N11 Strassen_p) (hmul_op M12 N21) in
    let R12 := hadd_op (hmul_op M11 N12) (hmul_op M12 N22) in
    let R21 := hadd_op (hmul_op M21 N11) (hmul_op M22 N21) in
    let R22 := hadd_op (hmul_op M21 N12) (hmul_op M22 N22) in
    hcast_op (esym (addpp1 p), esym (addpp1 p)) (block_op C R12 R21 R22).

Definition Strassen := unfold
  (positive_rect (fun p => (mxA p p -> mxA p p -> mxA p p))
                 (@Strassen_xI) (@Strassen_xO) (fun M N => hmul_op M N)).

End Strassen_generic.

Arguments Strassen_step {mxA _ _ _ _ _ _ _ p} A B f.
Arguments Strassen {mxA _ _ _ _ _ _ _ _ _ p} M N.

Section Strassen_correctness.

Import Refinements.Op.

Variable R : ringType.

Local Coercion nat_of_pos : positive >-> nat.

Local Open Scope ring_scope.

Instance : hadd (matrix R) := @addmx R.
Instance : hsub (matrix R) := (fun _ _ M N => addmx M (oppmx N)).
Instance : hmul (matrix R) := @mulmx R.
Instance : hcast (matrix R) := @castmx R.
Instance : ulsub (matrix R) := @ulsubmx R.
Instance : ursub (matrix R) := @ursubmx R.
Instance : dlsub (matrix R) := @dlsubmx R.
Instance : drsub (matrix R) := @drsubmx R.
Instance : block (matrix R) := @block_mx R.

Lemma Strassen_stepP (p : positive) (A B : 'M[R]_(p + p)) f :
  f =2 mulmx -> Strassen_step A B f = A *m B.
Proof.
move=> Hf; rewrite -{2}[A]submxK -{2}[B]submxK mulmx_block /Strassen_step !Hf.
rewrite /GRing.add /= /GRing.opp /=.
by congr block_mx; non_commutative_ring.
Qed.

Lemma mulmx_cast {R' : ringType} {m n p m' n' p'} {M:'M[R']_(m,p)} {N:'M_(p,n)}
  {eqm : m = m'} (eqp : p = p') {eqn : n = n'} :
  castmx (eqm,eqn) (M *m N) = castmx (eqm,eqp) M *m castmx (eqp,eqn) N.
Proof. by case eqm ; case eqn ; case eqp. Qed.

Lemma StrassenP p : param (refines_id ==> refines_id ==> refines_id) mulmx (Strassen (p := p)).
Proof.
rewrite paramE => a _ [<-] b _ [<-]; congr Some.
elim: p a b => // [p IHp|p IHp] M N.
  rewrite /= /unfold /Strassen_xI; case:ifP=> // _.
  by simpC; rewrite Strassen_stepP // -mulmx_block !submxK -mulmx_cast castmxK.
rewrite /= /unfold /Strassen_xO; case:ifP=> // _.
by simpC; rewrite Strassen_stepP // -mulmx_cast castmxK.
Qed.

End Strassen_correctness.

Section strassen_param.

Import Refinements.Op.

Local Coercion nat_of_pos : positive >-> nat.

Variable A : ringType.
Variable mxA : nat -> nat -> Type.

Context `{!hadd mxA, !hsub mxA, !hmul mxA, !hcast mxA}.
Context `{!ulsub mxA, !ursub mxA, !dlsub mxA, !drsub mxA, !block mxA}.

Context `{forall m n, refinement 'M[A]_(m,n) (mxA m n)}.
Context `{forall m n, param (refines ==> refines ==> refines)%C (@addmx A m n)
  (@hadd_op _ _ _ m n)}.
Context `{forall m n p, param (refines ==> refines ==> refines)%C (@mulmx A m n p)
  (@hmul_op _ _ _ m n p)}.

Instance param_elim_positive P P' (R : forall p, P p -> P' p -> Prop) 
  txI txI' txO txO' txH txH' : 
  (forall p, param (R p ==> R (p~1)%positive) (txI p) (txI' p)) ->
  (forall p, param (R p ==> R (p~0)%positive) (txO p) (txO' p)) ->
  (param (R 1%positive) txH txH') ->
  forall p, param (R p) (positive_rect P  txI  txO  txH p)
                        (positive_rect P' txI' txO' txH' p).
Admitted.

Import Parametricity.

Existing Instance StrassenP.
Global Instance refines_Strassen (p : positive) :
   param (refines ==> refines ==> refines)
         (@mulmx A p p p) 
         (@Strassen mxA _ _ _ _ _ _ _ _ _ p).
Proof.
eapply param_trans; tc.
apply set_param.
rewrite -[X in param X]/((fun p : positive => ((@refines _ _ (H p p))
 ==> @refines _ _ (H p p) ==> @refines _ _ (H p p))%C) p).
(* how to get this ??? *)
eapply (@param_elim_positive 
          (fun p0 : positive => 'M_p0 -> 'M_p0 -> 'M_p0) 
          (fun p0 : positive => mxA p0 p0 -> mxA p0 p0 -> mxA p0 p0)) => {p}.
  move=> p.
  apply get_param.
  rewrite /Strassen_xI.
  apply getparam_abstr => ???.
  apply getparam_abstr2 => ??? ???.
  apply set_param.
  apply param_if.
    by rewrite paramE. (* which rule should be used? *)
    tc.
Abort.

End strassen_param.

Section Strassen_seqmx.

Import Refinements.Op.

Variable A : Type.
Context `{add A, sub A, mul A, zero A}.




Definition Strassen_seqmx p := (Strassen (mxA := hseqmatrix A) (p := p)).



(*
Eval cbv delta[Strassen_seqmx Strassen] beta zeta in Strassen_seqmx.
*)

End Strassen_seqmx.