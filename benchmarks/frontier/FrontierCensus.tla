--------------------------- MODULE FrontierCensus ---------------------------
(***************************************************************************)
(* The census choreography of docs/polyglot-orbit-census-design.md,        *)
(* section 6, as one global specification. Roles: O (orchestrator), B      *)
(* (Bend challenger), M (Mojo authority).                                  *)
(*                                                                         *)
(*   O -> B : job(block)                                                   *)
(*   B -> O : proposal(good | bad | other) | fault                         *)
(*   O -> M : replay(proposal)                                             *)
(*   M -> O : verdict(accepted | rejected) | fault                         *)
(*   O      : ledger[block] := verdict                                     *)
(*                                                                         *)
(* "good" is the record the contract defines; "bad" is a well-formed wrong *)
(* record; "other" answers a different block (the echo check). M is        *)
(* modelled as correct: it accepts exactly the good proposal. That is the  *)
(* Mojo replay predicate's obligation, tested against the golden vectors,  *)
(* not something this model assumes away. B is arbitrary.                  *)
(*                                                                         *)
(* Each O action is one clause of Frontier.Protocol.step/2. Mutant selects *)
(* a deliberately broken orchestrator, so the test suite can show that the *)
(* invariants catch the faults they claim to catch.                        *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, Sequences

CONSTANTS Blocks, K, Mutant

ASSUME K \in Nat \ {0}
ASSUME Mutant \in {"none", "accept_unreplayed", "retry_after_verdict", "unbounded_retry"}

Proposals == {"good", "bad", "other"}
InFlight  == {"none", "job", "fault", "replay", "accepted", "rejected"} \cup
             {"proposal_" \o p : p \in Proposals}
Verdicts  == {"none", "accepted", "rejected", "exhausted"}

VARIABLES phase, attempts, inflight, proposal, ledger, replayed, verdictSeen
vars == <<phase, attempts, inflight, proposal, ledger, replayed, verdictSeen>>

TypeOK ==
  /\ phase \in [Blocks -> {"proposing", "replaying", "done"}]
  /\ attempts \in [Blocks -> 0..K+1]
  /\ inflight \in [Blocks -> InFlight]
  /\ proposal \in [Blocks -> Proposals \cup {"none"}]
  /\ ledger \in [Blocks -> Verdicts]
  /\ replayed \in [Blocks -> SUBSET Proposals]
  /\ verdictSeen \in [Blocks -> BOOLEAN]

\* Protocol.new/3 with no refusal: the first job is already sent.
Init ==
  /\ phase = [b \in Blocks |-> "proposing"]
  /\ attempts = [b \in Blocks |-> 1]
  /\ inflight = [b \in Blocks |-> "job"]
  /\ proposal = [b \in Blocks |-> "none"]
  /\ ledger = [b \in Blocks |-> "none"]
  /\ replayed = [b \in Blocks |-> {}]
  /\ verdictSeen = [b \in Blocks |-> FALSE]

Decide(b, v) ==
  /\ ledger' = [ledger EXCEPT ![b] = v]
  /\ phase' = [phase EXCEPT ![b] = "done"]
  /\ inflight' = [inflight EXCEPT ![b] = "none"]

\* B answers a job arbitrarily: any proposal, or a fault (crash, timeout, garbage).
BRespond(b) ==
  /\ inflight[b] = "job"
  /\ \E r \in {"proposal_" \o p : p \in Proposals} \cup {"fault"} :
       inflight' = [inflight EXCEPT ![b] = r]
  /\ UNCHANGED <<phase, attempts, proposal, ledger, replayed, verdictSeen>>

\* O receives a proposal for the block it asked about: send it for replay.
OProposal(b) ==
  /\ phase[b] = "proposing"
  /\ \E p \in {"good", "bad"} :
       /\ inflight[b] = "proposal_" \o p
       /\ proposal' = [proposal EXCEPT ![b] = p]
       /\ IF Mutant = "accept_unreplayed"
            THEN /\ Decide(b, "accepted")
                 /\ UNCHANGED <<attempts, replayed, verdictSeen>>
            ELSE /\ phase' = [phase EXCEPT ![b] = "replaying"]
                 /\ inflight' = [inflight EXCEPT ![b] = "replay"]
                 /\ replayed' = [replayed EXCEPT ![b] = @ \cup {p}]
                 /\ UNCHANGED <<attempts, ledger, verdictSeen>>

\* O receives an answer to a different block: the echo check rejects it.
OEcho(b) ==
  /\ phase[b] = "proposing"
  /\ inflight[b] = "proposal_other"
  /\ Decide(b, "rejected")
  /\ UNCHANGED <<attempts, proposal, replayed, verdictSeen>>

\* M replays: correct by obligation, but may fault like any process.
MRespond(b) ==
  /\ inflight[b] = "replay"
  /\ \E r \in {IF proposal[b] = "good" THEN "accepted" ELSE "rejected", "fault"} :
       inflight' = [inflight EXCEPT ![b] = r]
  /\ UNCHANGED <<phase, attempts, proposal, ledger, replayed, verdictSeen>>

OVerdict(b) ==
  /\ phase[b] = "replaying"
  /\ inflight[b] \in {"accepted", "rejected"}
  /\ verdictSeen' = [verdictSeen EXCEPT ![b] = TRUE]
  /\ IF Mutant = "retry_after_verdict" /\ inflight[b] = "rejected"
       THEN /\ phase' = [phase EXCEPT ![b] = "proposing"]
            /\ inflight' = [inflight EXCEPT ![b] = "job"]
            /\ UNCHANGED <<ledger, attempts>>
       ELSE /\ Decide(b, inflight[b])
            /\ UNCHANGED attempts
  /\ UNCHANGED <<proposal, replayed>>

\* An infrastructure fault: resend the outstanding message, at most K attempts in all.
OFault(b) ==
  /\ phase[b] \in {"proposing", "replaying"}
  /\ inflight[b] = "fault"
  /\ IF attempts[b] < K \/ Mutant = "unbounded_retry"
       THEN /\ attempts' = [attempts EXCEPT ![b] = IF @ > K THEN @ ELSE @ + 1]
            /\ inflight' = [inflight EXCEPT ![b] = IF phase[b] = "proposing" THEN "job" ELSE "replay"]
            /\ UNCHANGED <<phase, ledger>>
       ELSE /\ Decide(b, "exhausted")
            /\ UNCHANGED attempts
  /\ UNCHANGED <<proposal, replayed, verdictSeen>>

AllDone == \A b \in Blocks : phase[b] = "done"
Terminated == AllDone /\ UNCHANGED vars

Next ==
  \/ \E b \in Blocks : BRespond(b) \/ OProposal(b) \/ OEcho(b) \/ MRespond(b) \/ OVerdict(b) \/ OFault(b)
  \/ Terminated

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
NoAcceptWithoutReplay ==
  \A b \in Blocks : ledger[b] = "accepted" => proposal[b] = "good" /\ "good" \in replayed[b]

NoRetryAfterVerdict == \A b \in Blocks : verdictSeen[b] => inflight[b] # "job"

BoundedRestarts == \A b \in Blocks : attempts[b] <= K

DoneIffDecided == \A b \in Blocks : (phase[b] = "done") <=> (ledger[b] # "none")

WriteOnce == [][\A b \in Blocks : ledger[b] # "none" => ledger'[b] = ledger[b]]_vars

Termination == <>AllDone
=============================================================================
