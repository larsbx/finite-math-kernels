module MetaTest.Core
  ( OracleId (..)
  , SuiteId (..)
  , SubjectId (..)
  , SubjectArtifactId (..)
  , MutantId (..)
  , SeededFaultId (..)
  , PopulationId (..)
  , CorpusId (..)
  , ExecutionPolicyId (..)
  , ObservationBundleId (..)
  , ObservationRunId (..)
  , Partition (..)
  , SubjectClass (..)
  , SubjectDescriptor (..)
  , PopulationManifest (..)
  , CorpusManifest (..)
  , PopulationAdequacy (..)
  , Power (..)
  ) where

import Data.Text (Text)

newtype OracleId = OracleId Text
  deriving (Eq, Ord, Show)

newtype SuiteId = SuiteId Text
  deriving (Eq, Ord, Show)

newtype SubjectId = SubjectId Text
  deriving (Eq, Ord, Show)

newtype SubjectArtifactId = SubjectArtifactId Text
  deriving (Eq, Ord, Show)

newtype MutantId = MutantId Text
  deriving (Eq, Ord, Show)

newtype SeededFaultId = SeededFaultId Text
  deriving (Eq, Ord, Show)

newtype PopulationId = PopulationId Text
  deriving (Eq, Ord, Show)

newtype CorpusId = CorpusId Text
  deriving (Eq, Ord, Show)

newtype ExecutionPolicyId = ExecutionPolicyId Text
  deriving (Eq, Ord, Show)

newtype ObservationBundleId = ObservationBundleId Text
  deriving (Eq, Ord, Show)

-- Assigned by the observation requester, independently of returned evidence.
-- This is an S0 identity, not an authenticated nonce or a stable CID.
newtype ObservationRunId = ObservationRunId Text
  deriving (Eq, Ord, Show)

data Partition
  = Shown
  | Judge
  deriving (Eq, Ord, Show)

data SubjectClass
  = Reference
  | Mutant MutantId
  | Seeded SeededFaultId
  deriving (Eq, Ord, Show)

data SubjectDescriptor = SubjectDescriptor
  { subjectDescriptorId :: SubjectId
  , subjectDescriptorArtifactId :: SubjectArtifactId
  , subjectDescriptorClass :: SubjectClass
  }
  deriving (Eq, Ord, Show)

data PopulationManifest = PopulationManifest
  { populationManifestId :: PopulationId
  , populationSubjects :: [SubjectDescriptor]
  , minimumMutants :: Int
  }
  deriving (Eq, Show)

newtype CorpusManifest = CorpusManifest
  { corpusManifestId :: CorpusId
  }
  deriving (Eq, Ord, Show)

data PopulationAdequacy = PopulationAdequacy
  { observedMutants :: Int
  , requiredMutants :: Int
  }
  deriving (Eq, Ord, Show)

data Power
  = PopulationInadequate PopulationAdequacy
  | DefinedKillRate Rational
  deriving (Eq, Show)
