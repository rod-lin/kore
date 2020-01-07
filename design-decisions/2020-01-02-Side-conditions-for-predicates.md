Side conditions for predicates
==============================

Background
----------

Let us say that we have a `sgn` function defined in the usual way:
```
sgn(x) = -1 requires x < 0
sgn(x) = 0 requires x == 0
sgn(x) = 1 requires x > 0
```

Let us also say that we're trying to simplify this top-level configuration:
`sgn(x) and x > 1`. Then it should be obvious that this evaluates uniquely to
`1 and x > 1`, and we can solve that by passing the top-level condition,
`x > 1`, as a side condition to the function simplifier, which can then use it
to prune the unfeasible branches.

The problem
-----------

The main question is what to use as a side condition when simplifying other
predicates in a way that makes sense. The predicate can be either the
top-level one or it could be generated by something like unification or
function application simplification.

One interesting issue is how to simplify the predicate `sgn(x)==1`.

Decision
--------

Use the top-level predicate in the short term (partly implemented in the PR
that added this document). In the long term, use the combined version below.

Options
-------

### Use the top-level predicate

Except when simplifying the top condition, we can safely use the top-level
predicate as a side condition. When simplifying the top condition we can safely
use the previous top condition (for the first iteration we can just use `⊤`).
This would allow us to simplify many predicates, but would fail for `sgn(x)==1`.

### Conditions as their own side conditions

We could try to use a condition as its own side-condition.

The intuition would be that, when simplifying the `sgn(x)` part from
`sgn(x) == 1 and x > 1` the SMT can use `x>1` to prune all branches except one.
When simplifying `sgn(x) == 1`, the SMT may again prune all branches except one
(assuming that it has the definition for `sgn`).

The main problem is that the side condition cannot be used to prune unneeded
predicates, which seems to be a priority right now. Normally, if the top-level
predicate is `x>1` and we evaluate `sgn(x)` to `1 and x>0`, then, since `x>1`
implies `x>0`, we can safely drop `x>0` from the evaluation result and keep
only the `1` part.

However, if we try that when evaluating `sgn(x)==1` with itself as a side
condition, say, because `sgn(x)==1` is the top predicate, we would get just
`⊤` (since `sgn(x)==1` implies `x>0` and we'll drop it), which is obviously
wrong.

### Combining the two

We could do a two-step simplification (not implemented at the time
when this document is being written). If `C` is the top-level condition:

1. Let us say that a sub-term `σ` of a predicate `P` yields
   `σ = φ₁ ∨ ... ∨ φₙ`.
1. We filter the resulting disjunction by evaluating `φᵢ` under the condition
   `C ∧ P ∧ (σ = φᵢ)`.
    1. In the usual case, `σ` is a function-like pattern, and at most one of
       `φᵢ` is defined. Note that this is not always the case, since evaluating
       `sgn(x)` as part of `ceil(1/sgn(x))` with a `⊤` top-level condition
       will still branch.
1. Assuming that only one `φᵢ` is defined, we can sometimes simplify its
   condition by using `C`, i.e. if `φᵢ = tᵢ ∧ Rᵢ` with `Rᵢ` being a predicate,
   and `C` implies `Rᵢ`, then we can simply drop `Rᵢ`).

Additionally, a predicate `P` can be written as `P = P₁ ∧ ... ∧ Pₙ`, usually
with `n>1`. Then we can simplify it as follows:
1. We simplify `P₁` as described above, but in the last step we check whether
   `C ∧ P₂ ... ∧ Pₙ` implies `Rᵢ`. Let `Q₁` be the result.
1. We simplify `P₂` as above, in the last step we check whether
   `C ∧ Q₁ ∧ P₃ ... ∧ Pₙ` implies `Rᵢ`. Let `Q₂` be the result.
1. In general, we simplify `Pⱼ` as above, in the last step we check
   whether `C ∧ Q₁ ∧ ... ∧ Qⱼ₋₁ ∧ Pⱼ₊₁ ... ∧ Pₙ` implies `Rᵢ`.
   Let `Qⱼ` be the result.

Note that when simplifying `Pⱼ` we can't just take all `Pₖ` except `Pⱼ` as a
side predicate in the last step since we don't want to simplify
`sgn(x)==1 ∧ x>0` to `⊤`.