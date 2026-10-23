module MetaTest.Outcome
  ( ExceptionInfo (..)
  , ExitInfo (..)
  , TimeoutInfo (..)
  , ResourceLimitInfo (..)
  , SpawnFailureInfo (..)
  , Outcome (..)
  ) where

import Data.Text (Text)

newtype ExceptionInfo = ExceptionInfo
  { exceptionMessage :: Text
  }
  deriving (Eq, Ord, Show)

data ExitInfo = ExitInfo
  { exitCode :: Int
  , exitStdout :: Text
  , exitStderr :: Text
  }
  deriving (Eq, Ord, Show)

newtype TimeoutInfo = TimeoutInfo
  { timeoutLabel :: Text
  }
  deriving (Eq, Ord, Show)

newtype ResourceLimitInfo = ResourceLimitInfo
  { resourceLimitLabel :: Text
  }
  deriving (Eq, Ord, Show)

newtype SpawnFailureInfo = SpawnFailureInfo
  { spawnFailureMessage :: Text
  }
  deriving (Eq, Ord, Show)

data Outcome a
  = Returned a
  | Raised ExceptionInfo
  | Exited ExitInfo
  | TimedOut TimeoutInfo
  | ResourceLimited ResourceLimitInfo
  | SpawnFailed SpawnFailureInfo
  deriving (Eq, Ord, Show)
