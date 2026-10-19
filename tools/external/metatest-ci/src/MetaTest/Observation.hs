module MetaTest.Observation
  ( Observation (..)
  , ObservationManifest (..)
  , ObservationBundle
  , mkObservationBundle
  , mkBoundObservationBundle
  , observationBundleId
  , observationExecutionPolicyId
  , observationManifest
  , bundleObservations
  , observationsFor
  , restrictBundle
  ) where

import MetaTest.Core
  ( CorpusManifest
  , ExecutionPolicyId
  , ObservationBundleId
  , ObservationRunId
  , PopulationManifest
  , SubjectId
  )
import MetaTest.Outcome (Outcome)

data Observation a b = Observation
  { observationSubject :: SubjectId
  , observationInput :: a
  , observationOutcome :: Outcome b
  }
  deriving (Eq, Ord, Show)

-- Snapshot the declared sources before observation. Full inputs/descriptors
-- prevent reused placeholder IDs from hiding changed corpus or artifact data.
-- This manifest is declared development provenance, not custody or attestation.
data ObservationManifest a = ObservationManifest
  { manifestRunId :: ObservationRunId
  , manifestCorpus :: CorpusManifest
  , manifestInputs :: [a]
  , manifestPopulation :: PopulationManifest
  , manifestExecutionPolicyId :: ExecutionPolicyId
  }
  deriving (Eq, Show)

data ObservationBundle a b = ObservationBundle
  { observationBundleId :: ObservationBundleId
  , observationExecutionPolicyId :: ExecutionPolicyId
  , observationManifest :: Maybe (ObservationManifest a)
  , bundleObservations :: [Observation a b]
  }
  deriving (Eq, Show)

mkObservationBundle
  :: ObservationBundleId
  -> ExecutionPolicyId
  -> [Observation a b]
  -> ObservationBundle a b
mkObservationBundle bundleId policyId =
  ObservationBundle bundleId policyId Nothing

-- Keep the legacy constructor for raw checking/scoring. Provenance-aware
-- acceptance requires this constructor and an independent expected manifest.
mkBoundObservationBundle
  :: ObservationBundleId
  -> ObservationManifest a
  -> [Observation a b]
  -> ObservationBundle a b
mkBoundObservationBundle bundleId manifest =
  ObservationBundle bundleId (manifestExecutionPolicyId manifest) (Just manifest)

observationsFor :: SubjectId -> ObservationBundle a b -> [Observation a b]
observationsFor subject =
  filter ((== subject) . observationSubject) . bundleObservations

restrictBundle :: SubjectId -> ObservationBundle a b -> ObservationBundle a b
restrictBundle subject bundle =
  bundle {bundleObservations = observationsFor subject bundle}
