from tools.cyclotomic_reference import cyclotomic, product_identity


def test_known_cyclotomic_polynomials():
    assert cyclotomic(1) == (-1, 1)
    assert cyclotomic(2) == (1, 1)
    assert cyclotomic(3) == (1, 1, 1)
    assert cyclotomic(4) == (1, 0, 1)
    assert cyclotomic(6) == (1, -1, 1)
    assert cyclotomic(8) == (1, 0, 0, 0, 1)
    assert cyclotomic(9) == (1, 0, 0, 1, 0, 0, 1)
    assert cyclotomic(10) == (1, -1, 1, -1, 1)
    assert cyclotomic(12) == (1, 0, -1, 0, 1)


def test_product_identity_through_32():
    assert all(product_identity(n) for n in range(1, 33))
