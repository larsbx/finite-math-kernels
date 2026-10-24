# Exact chromogeometry

`kernel/chromogeometry/chromatic.mojo` is the shared *domain-neutral* implementation of planar chromatic quadratic forms, polar bilinear forms, alternating determinant, and guarded spread laws over an `ExactField`.

The blue/red/green forms are x²+y², x²−y², 2xy. Polarization uses b(u,v)=(Q(u+v)-Q(u)-Q(v))/2; `chromo_*_spread` computes 1-b²/(Q(u)Q(v)) **only in odd characteristic** when both quadrances are nonzero. It returns a rejected field element if the domain is invalid or input rejected. Invalid color IDs fail closed.

The implemented identities are: Q_b²=Q_r²+Q_g²; the common Gram determinant law Q_c(u)Q_c(v)-b_c(u,v)²=det(M_c)det(u,v)²; and 1/s_b+1/s_r+1/s_g=2 with nonzero spread guards.

Use `projective_limits/rotor.mojo` for the existing full rotation-group and spread-polynomial library; this module does not copy it.

## Consumer boundary

`larsbx/finite-swarm-dynamics` owns agents, interaction topologies, updates, finite consensus and orbit classifications. `finite-math-kernels` owns the mathematical functions shared across consumers.

## Local check

`pixi run test-chromogeometry` or `mojo run -I kernel tests/chromogeometry/test_chromogeometry.mojo`.

The test exhaustively iterates vectors over F_7 and F_13 and checks selected rational-field examples; this is computational validation, **not** a universal formal proof.
