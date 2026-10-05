"""What a regression test stands for, declared by the test itself.

A consumer that asks every new piece of executable mathematical machinery
for Mojo regression coverage of its contract still needs something that links
a test file to the claim in its `claim_governance.toml` whose certificate that
contract supports. These two calls are that link, in the shape
`larsbx/crypto-composer` uses for its proof-driven tests: a test declares a
claim it guards, or states the contract it guards when no ledger claim is
the right target, and the `coverage` check of the
`claim_governance` package (`tools/claim_governance/checks/coverage.py`) reports a test that declares neither, a name
outside the ledger, and a claim the policy requires guarded that no test
names.

A declaration is both text and an act. Statically it is read out of the
source; at run time it prints a receipt line, `claim-receipt: <name>` or
`contract-receipt: <text>`, and the consumer's test runner collects the receipts of a
run into `build/claim-receipts.tsv`. So a declaration placed at the end of
`main`, after the assertions it stands behind, is reached only when they all
passed, and a claim whose only test body is never called from `main` is
reported as uncovered rather than credited.

A declaration is not evidence. It records which contract a test guards; that
the contract holds is what the test's assertions decide, and that the claim
follows from the contract is what its own proof or certificate decides.
"""


def require_claim(claim: String) raises:
    """Declare that this test guards a contract the named ledger claim rests
    on. The name must be a claim name or alias in `claim_governance.toml`."""
    if claim.byte_length() == 0:
        raise Error("require_claim: a test must name the claim it guards")
    print("claim-receipt:", claim)


def require_contract(contract: String) raises:
    """Declare the contract this test guards when no ledger claim is its
    target: a vendored kernel's arithmetic, or a shared primitive that
    several claims rest on without being one."""
    if contract.byte_length() == 0:
        raise Error("require_contract: a test must state the contract it guards")
    print("contract-receipt:", contract)
