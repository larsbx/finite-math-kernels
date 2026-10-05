--------------------------- MODULE ProofArchitecture ---------------------------
(***************************************************************************)
(* Generic dependency state machine for a ledger of named proof records.    *)
(*                                                                         *)
(* A result is established only by explicit assumption or by discharging a  *)
(* standing proved theorem after one prerequisite branch is established.   *)
(* Withdrawn results can never be discharged.                               *)
(*                                                                         *)
(* Requires encodes one-way proof sufficiency/dependency. It must not be     *)
(* read as a converse mathematical implication.                              *)
(*                                                                         *)
(* All currently ready results are discharged in one batch. This computes   *)
(* the same least dependency closure as arbitrary one-at-a-time discharge,   *)
(* but avoids exploring factorially many equivalent proof orders as the      *)
(* ledger grows. Each non-stuttering step advances one dependency layer.     *)
(***************************************************************************)
EXTENDS FiniteSets

CONSTANTS
    Results,
    Requires,
    Proved,
    Withdrawn,
    Assumed

ASSUME
    /\ Proved \subseteq Results
    /\ Withdrawn \subseteq Results
    /\ Assumed \subseteq Results
    /\ Proved \cap Withdrawn = {}
    /\ Requires \in [Results -> SUBSET (SUBSET Results)]

VARIABLE established

vars == <<established>>

Init == established = Assumed

(* Each branch is a conjunction; branches are alternatives. {{}} is unconditional. *)
DependencyRoutes(r) == Requires[r]

Ready == {
    r \in (Proved \ established) :
        \E branch \in DependencyRoutes(r) :
            /\ branch \subseteq established
            /\ branch \cap Withdrawn = {}
}

Next ==
    /\ Ready # {}
    /\ established' = established \cup Ready

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
(* Soundness invariants *)

TypeOK == established \subseteq Results

NothingUnjustified == established \subseteq (Proved \cup Assumed)

NoWithdrawnDependency ==
    /\ established \cap Withdrawn = {}
    /\ \A r \in established :
        \E branch \in DependencyRoutes(r) : branch \cap Withdrawn = {}

-----------------------------------------------------------------------------
(* Observables are configuration-specific and live in the generated ledger   *)
(* module (proof_records/generate_ledgers.py): one `<Name>NotEstablished` per result. *)
(* A model asserts them negatively for the results its assumptions leave      *)
(* unreachable, so that a TLC violation trace demonstrates a derivation.      *)

=============================================================================
