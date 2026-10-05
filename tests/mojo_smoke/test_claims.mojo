"""A declaration prints its receipt, and an empty one is refused.

Run with `pixi run test-claims`; `tests/mojo_smoke/test_claims_receipts.py`
reads the receipts this prints.
"""

from mojo_smoke.claims import require_claim, require_contract


def refuses_empty_claim() -> Bool:
    try:
        require_claim("")
        return False
    except:
        return True


def refuses_empty_contract() -> Bool:
    try:
        require_contract("")
        return False
    except:
        return True


def main() raises:
    if not refuses_empty_claim() or not refuses_empty_contract():
        raise Error("an empty declaration was accepted")
    require_claim("ExampleClaim")
    require_contract("receipts are printed after the assertions they stand behind")
