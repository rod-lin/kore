module Test.Kore.Step.Simplification.TermLike (
    test_simplify_sideConditionReplacements,
) where

import Control.Monad.Catch (
    MonadThrow,
 )
import Kore.Internal.OrPattern (
    OrPattern,
 )
import qualified Kore.Internal.OrPattern as OrPattern
import Kore.Internal.Predicate (
    makeAndPredicate,
    makeEqualsPredicate,
 )
import Kore.Internal.SideCondition (
    SideCondition,
 )
import qualified Kore.Internal.SideCondition as SideCondition
import Kore.Internal.TermLike
import Kore.Rewriting.RewritingVariable (
    getRewritingPattern,
    mkConfigVariable,
    mkRewritingTerm,
 )
import qualified Kore.Step.Function.Memo as Memo
import Kore.Step.Simplification.Simplify
import qualified Kore.Step.Simplification.TermLike as TermLike
import qualified Logic
import Prelude.Kore
import qualified Test.Kore.Step.MockSymbols as Mock
import Test.Kore.Step.Simplification
import Test.Tasty
import Test.Tasty.HUnit

test_simplify_sideConditionReplacements :: [TestTree]
test_simplify_sideConditionReplacements =
    [ testCase "Replaces top level term" $ do
        let sideCondition =
                f a `equals` b
                    & SideCondition.fromPredicate
            term = f a
            expected = b & OrPattern.fromTermLike
        actual <-
            simplifyWithSideCondition
                sideCondition
                term
        assertEqual "" expected actual
    , testCase "Replaces nested term" $ do
        let sideCondition =
                f a `equals` b
                    & SideCondition.fromPredicate
            term = g (f a)
            expected = g b & OrPattern.fromTermLike
        actual <-
            simplifyWithSideCondition
                sideCondition
                term
        assertEqual "" expected actual
    , testCase "Replaces terms in sequence" $ do
        let sideCondition =
                (f a `equals` g b) `and'` (g b `equals` c)
                    & SideCondition.fromPredicate
            term = f a
            expected = c & OrPattern.fromTermLike
        actual <-
            simplifyWithSideCondition
                sideCondition
                term
        assertEqual "" expected actual
    , testCase "Replaces top level term after replacing subterm" $ do
        let sideCondition =
                (f a `equals` b) `and'` (g b `equals` c)
                    & SideCondition.fromPredicate
            term = g (f a)
            expected = c & OrPattern.fromTermLike
        actual <-
            simplifyWithSideCondition
                sideCondition
                term
        assertEqual "" expected actual
    ]
  where
    f = Mock.f
    g = Mock.g
    a = Mock.a
    b = Mock.b
    c = Mock.c
    equals = makeEqualsPredicate
    and' = makeAndPredicate

simplifyWithSideCondition ::
    SideCondition VariableName ->
    TermLike VariableName ->
    IO (OrPattern VariableName)
simplifyWithSideCondition
    (SideCondition.mapVariables (pure mkConfigVariable) -> sideCondition) =
        fmap (OrPattern.map getRewritingPattern)
            <$> runSimplifier Mock.env
                . TermLike.simplify sideCondition
                . mkRewritingTerm

newtype TestSimplifier a = TestSimplifier {getTestSimplifier :: SimplifierT NoSMT a}
    deriving newtype (Functor, Applicative, Monad)
    deriving newtype (MonadLog, MonadSMT, MonadThrow)

instance MonadSimplify TestSimplifier where
    askMetadataTools = TestSimplifier askMetadataTools
    askSimplifierAxioms = TestSimplifier askSimplifierAxioms
    localSimplifierAxioms f =
        TestSimplifier . localSimplifierAxioms f . getTestSimplifier
    askMemo = TestSimplifier (Memo.liftSelf TestSimplifier <$> askMemo)
    askInjSimplifier = TestSimplifier askInjSimplifier
    askOverloadSimplifier = TestSimplifier askOverloadSimplifier
    simplifyCondition sideCondition condition =
        Logic.mapLogicT
            TestSimplifier
            (simplifyCondition sideCondition condition)

    -- Throw an error if any term would be simplified.
    simplifyTermLike = undefined
