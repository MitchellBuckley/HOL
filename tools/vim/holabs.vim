iab <buffer> /\ ∧
"dig AN
iab <buffer> \/ ∨
"dig OR
iab <buffer> ~ ¬
"dig NO
"dig -,
iab <buffer> ==> ⇒
"dig =>
iab <buffer> <= ≤
"dig =<
iab <buffer> >= ≥
"dig >=
iab <buffer> <=> ⇔
"dig ==
iab <buffer> <> ≠
"dig !=
iab <buffer> ! ∀
"dig FA
iab <buffer> ? ∃
"dig TE
iab <buffer> \ λ
"dig l*
iab <buffer> IN ∈
"dig (- ∈
iab <buffer> NOTIN ∉
dig (+ 8713
iab <buffer> INTER ∩
"dig (U
iab <buffer> UNION ∪
"dig U)
iab <buffer> SUBSET ⊆
"dig (_
iab <buffer> PSUBSET ⊂
"dig (C
set iskeyword+=>,/,\
fu! HOLUnab ()
  s/∧/\/\\/eg
  s/∨/\\\//eg
  s/¬/~/eg
  s/⇒/==>/eg
  s/≤/<=/eg
  s/≥/>=/eg
  s/⇔/<=>/eg
  s/≠/<>/eg
  s/∀/!/eg
  s/∃/?/eg
  s/λ/\\/eg
  s/∈/IN/eg
  s/∉/NOTIN/eg
  s/∪/UNION/eg
  s/∩/INTER/eg
  s/⊆/SUBSET/eg
  s/⊂/PSUBSET/eg
endf
