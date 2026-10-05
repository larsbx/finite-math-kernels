# projective: the quadratic map on the projective line, over interval boxes.
#
#   homogeneous   a pair of coordinate records modulo scaling, the degree-2
#                 lift of z^2 + c, and the three-valued tests that say when a
#                 pair is degenerate, when two pairs are provably different
#                 classes, and when a pair is the fixed class at infinity.
#   chart         the two affine charts and the maps between them, each with
#                 a stated domain: a chart is a division, so it is undefined
#                 where a quadrance interval contains zero.
#
# Which completion this is, stated once: the projective line over the complex
# numbers, where z^2 + c extends as a morphism of degree two and infinity is a
# fixed class of the algebra rather than a limit. It is NOT the completion in
# which the plane acquires an ideal line carrying the circular points; the
# quadrance form degenerates there, and this map is not a morphism of it.
# A consumer that conflates the two is wrong whatever it proves.
#
# A homogeneous pair is not an ideal point. It is two coordinate records taken
# modulo scaling, every operation on it here is polynomial, and reading one as
# a value requires naming a chart. Nothing in this package raises, aborts, or
# decides certificate acceptance; a box that leaves a chart's domain comes
# back rejected, never guessed.
