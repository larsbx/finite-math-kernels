# Beta-numeration: exact quadratic carry contract (2026-11-27)

Research design note; written derivation, not a compiled Lean theorem, implementation, or new literature claim.

## Scope and prior art

For an integer m >= 1, let beta = (m + sqrt(m^2+4))/2, D = {0,...,m}, and pi(d) = sum_{i>=1} d_i beta^{-i}. The conjugate is -1/beta and beta^2=m beta+1. At m=1 this is the golden ratio. Metallic means are not generally the generalized golden-ratio thresholds of univoque theory. General Pisot finite-state normalization is established prior art (see [Frougny, Numeration systems and automata, FPSAC 1993](https://fpsac-archive.github.io/FPSAC93/ARTICLES/Frougny.pdf)); do not claim a new general decidability theorem.

## Exact proposed interface and derivation

For d,e in D^N define c_0=0 and c_{n+1}=beta c_n+d_{n+1}-e_{n+1}. Writing c_n=a+b beta, the integer step is (a,b) -> (b+d-e,a+mb).

Claim to certify: equal infinite valuations iff every c_n lies in the seven-state set S={0, +/-1, +/-beta^{-1}, +/- (1+beta^{-1})}. In coordinates this is (0,0), +/-(1,0), +/-(−m,1), +/-(1−m,1).

Necessity: cancellation of the infinite tails gives |c_n| <= m/(beta-1)=1+1/beta. The conjugate recurrence from zero gives |c'_n| < m/(1-1/beta)=beta+1 (strict for each finite n). Consequently |b| < (beta+1 + 1+1/beta)/(beta+1/beta) < 2. For b=0 the real bound forces a in {-1,0,1}. For b=1 the real bound gives a between -m-1-2/beta and 1-m; the strict conjugate bound gives a > -m-1, leaving -m and 1-m. Negation handles b=-1. Sufficiency: partial value difference is beta^{-n} c_n, tending to zero. These bounds are exact; no empirical slack or floating point is warranted. Seven states is a sufficient carrier, not a minimality claim.

For finite equal-length words use terminal zero; for infinite streams require every prefix to stay in S, not repeated returns to zero. Add sticky divergence to identify distinct streams. With finite graphs presenting infinite paths, test a reachable cycle after divergence in the product graph, retaining an actual labeled prefix and cycle; for other acceptance conditions use the appropriate omega-language emptiness algorithm. Do not apply finite DFA projection/complement as though it were infinite-word semantics.

## Boundary controls and acceptance plan

- m=1: 100 and 011 have equal finite value; 1000... and 010101... have equal infinite value and both avoid 11. The latter is a negative control for terminal-zero acceptance and for uniqueness based solely on forbidden 11.
- Check all digit-pair transitions for each tested m, malformed digits and out-of-carrier transitions, signed-coordinate overflow refusal, strict conjugate endpoints, and a fabricated witness with the wrong label. Finite tests never substitute for all-m/all-stream proof.
- Implement a canonical Mojo exact kernel upstream using checked or BigZ arithmetic, an independent Python oracle, Lean valuation/recurrence and carrier completeness, then labeled graph witness soundness/completeness and correspondence receipts. No new code or proof artifacts in this note; no gates were executed locally. Future gates: pixi run test, test-audit, test-provenance, references, property, test-polyglot, and the Lean verification lane.
- Reuse [DFA products and BigZ counting](../kernel/finite_automata/dfa.mojo), finite_graph SCC/cycle routines, and [Lean verification scope](lean-verification.md); do not silently upgrade existing finite conformance to implementation refinement. The N3 overflow [issue #97](https://github.com/larsbx/finite-math-kernels/issues/97) reinforces exact-count boundaries.

## Consumers and ownership

- [PSC numeration applications and literature stop/go](https://github.com/larsbx/pisot-substitution-conjecture-research/blob/main/docs/beta-numeration-research-route-2026-11-27.md), including uniqueness/multiplicity, constrained language and tiling valuation bridges. Existing [conversion](https://github.com/larsbx/pisot-substitution-conjecture-research/blob/8bf2a627913bb7a9eb2f05b0ed3f08c54dc647d7/kernel/psc/numeration_conversion.mojo) and [carry reserve](https://github.com/larsbx/pisot-substitution-conjecture-research/blob/8bf2a627913bb7a9eb2f05b0ed3f08c54dc647d7/kernel/psc/pisot_state.mojo) are precedents, not fractional-stream proofs.
- [Golden-ratio normality statistical bridge](https://github.com/larsbx/golden-ratio-normality-research/blob/main/docs/beta-numeration-statistics-2026-11-27.md): reusable block counting, separate measures and integer-base normality target.

Proceed with the narrowed proof increment, not a new claim about PSC or normality. Consumer integration must use a reviewed upstream commit and explicit vendoring/pin updates; this documentation changes no facade, pin, claim ledger, or executable code.
