from claim_governance.lexing import (
    find_all,
    has_context,
    mask_comments_and_strings,
    mask_fenced_code,
    mask_tex_comments,
    window_lines,
)


def test_mask_preserves_code_and_line_numbers():
    source = 'fn degree(p: Poly) -> Int:\n    return p.degree # angle and sin\n'
    masked = mask_comments_and_strings(source)
    assert "fn degree" in masked and "return p.degree" in masked
    assert "angle" not in masked
    assert masked.count("\n") == source.count("\n")
    assert len(masked) == len(source)


def test_mask_removes_single_and_triple_quoted_strings():
    source = 'var label = "sin degrees"\n"""polar angle\nunit circle"""\ncos(x)\n'
    masked = mask_comments_and_strings(source)
    assert "sin" not in masked and "polar angle" not in masked and "unit circle" not in masked
    assert "cos(x)" in masked
    assert masked.count("\n") == source.count("\n")


def test_mask_handles_escaped_quotes_and_unterminated_comment():
    assert "cos" not in mask_comments_and_strings('var label = "not \\"cos\\" code"\ntan(x)\n')
    assert mask_comments_and_strings("x = 1 # trailing") == "x = 1           "


def test_mask_tex_comments_keeps_escaped_percent():
    tex = "50\\% of cases % sin(x) here\nnext line\n"
    masked = mask_tex_comments(tex)
    assert "50\\%" in masked and "sin" not in masked and "next line" in masked
    assert masked.count("\n") == tex.count("\n")


def test_mask_fenced_code_blanks_bodies_only():
    md = "prose\n```text\nG1 [PROVED]\n```\nafter\n"
    masked = mask_fenced_code(md)
    assert "PROVED" not in masked and "prose" in masked and "after" in masked
    assert masked.count("\n") == md.count("\n")


def test_find_all_word_boundaries_and_context():
    text = "G1 holds; G1-free route; not G1 either"
    assert list(find_all(text, "G1")) == [0, 10, 29]
    assert list(find_all(text, "G1", word=True)) == [0, 29]
    assert has_context(text, 29, ("not ",), radius=5)
    assert not has_context(text, 0, ("not ",), radius=5)


def test_window_lines_is_inclusive_of_following_lines():
    assert window_lines("a\nb\nc\nd", 2, 1) == "b\nc"
    assert window_lines("a\nb", 2, 5) == "b"


def test_keep_strings_blanks_only_comments():
    source = 'x = Status("OPEN_FRONTIER")  # PROVED in a comment\n"""doc PROVED"""\n'
    masked = mask_comments_and_strings(source, keep_strings=True)
    assert 'Status("OPEN_FRONTIER")' in masked and "doc PROVED" in masked
    assert "in a comment" not in masked and len(masked) == len(source)
