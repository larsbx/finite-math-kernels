module MetaTest.Execution
  ( ProcessExecutionPolicy (..)
  , ExecutionConfigError (..)
  , WorkerCount
  , mkWorkerCount
  , ProcessOutput (..)
  , TextProcessSubject
  , mkTextProcessSubject
  , runTextSubject
  , runTextSubjectCaptured
  , observeTextProcesses
  , observeTextProcessesWithWorkers
  ) where

import Control.Concurrent.QSem
  ( newQSem
  , signalQSem
  , waitQSem
  )
import Control.Concurrent.Async (mapConcurrently)
import Control.Exception
  ( IOException
  , bracket_
  , try
  )
import Data.List (sortOn)
import qualified Data.Text as Text
import MetaTest.Core
  ( ExecutionPolicyId
  , ObservationBundleId
  , SubjectId
  )
import MetaTest.Observation
  ( Observation (..)
  , ObservationBundle
  , mkObservationBundle
  )
import MetaTest.Outcome
  ( ExitInfo (..)
  , Outcome (..)
  , SpawnFailureInfo (..)
  , TimeoutInfo (..)
  )
import System.Exit (ExitCode (..))
import System.Process
  ( CreateProcess (..)
  , proc
  , readCreateProcessWithExitCode
  )
import System.Timeout (timeout)

data ProcessExecutionPolicy = ProcessExecutionPolicy
  { processExecutionPolicyId :: ExecutionPolicyId
  , processTimeoutMicros :: Int
  }
  deriving (Eq, Show)

data ExecutionConfigError
  = InvalidWorkerCount Int
  deriving (Eq, Ord, Show)

newtype WorkerCount = WorkerCount Int
  deriving (Eq, Ord, Show)

mkWorkerCount :: Int -> Either ExecutionConfigError WorkerCount
mkWorkerCount count
  | count > 0 = Right (WorkerCount count)
  | otherwise = Left (InvalidWorkerCount count)

data ProcessOutput = ProcessOutput
  { processStdout :: Text.Text
  , processStderr :: Text.Text
  }
  deriving (Eq, Ord, Show)

data TextProcessSubject a = TextProcessSubject
  { textProcessSubjectId :: SubjectId
  , textProcessCommand :: FilePath
  , textProcessArguments :: a -> [String]
  , textProcessWorkingDirectory :: Maybe FilePath
  }

mkTextProcessSubject
  :: SubjectId
  -> FilePath
  -> (a -> [String])
  -> Maybe FilePath
  -> TextProcessSubject a
mkTextProcessSubject = TextProcessSubject

runTextSubject
  :: ProcessExecutionPolicy
  -> TextProcessSubject a
  -> a
  -> IO (Outcome Text.Text)
runTextSubject policy subject input =
  projectStdout <$> runTextSubjectCaptured policy subject input

runTextSubjectCaptured
  :: ProcessExecutionPolicy
  -> TextProcessSubject a
  -> a
  -> IO (Outcome ProcessOutput)
runTextSubjectCaptured policy subject input = do
  result <-
    timeout
      (processTimeoutMicros policy)
      ( try
          ( readCreateProcessWithExitCode
              ( (proc (textProcessCommand subject) (textProcessArguments subject input))
                  { cwd = textProcessWorkingDirectory subject
                  }
              )
              ""
          )
          :: IO (Either IOException (ExitCode, String, String))
      )
  pure $
    case result of
      Nothing ->
        TimedOut
          (TimeoutInfo (Text.pack ("deadline-micros=" ++ show (processTimeoutMicros policy))))
      Just (Left err) ->
        SpawnFailed (SpawnFailureInfo (Text.pack (show err)))
      Just (Right (ExitSuccess, stdoutText, stderrText)) ->
        Returned
          ProcessOutput
            { processStdout = Text.pack stdoutText
            , processStderr = Text.pack stderrText
            }
      Just (Right (ExitFailure code, stdoutText, stderrText)) ->
        Exited
          ExitInfo
            { exitCode = code
            , exitStdout = Text.pack stdoutText
            , exitStderr = Text.pack stderrText
            }

projectStdout :: Outcome ProcessOutput -> Outcome Text.Text
projectStdout outcome =
  case outcome of
    Returned output -> Returned (processStdout output)
    Raised info -> Raised info
    Exited info -> Exited info
    TimedOut info -> TimedOut info
    ResourceLimited info -> ResourceLimited info
    SpawnFailed info -> SpawnFailed info

observeTextProcesses
  :: ProcessExecutionPolicy
  -> ObservationBundleId
  -> [TextProcessSubject a]
  -> [a]
  -> IO (ObservationBundle a Text.Text)
observeTextProcesses =
  observeTextProcessesWithWorkers (WorkerCount 1)

observeTextProcessesWithWorkers
  :: WorkerCount
  -> ProcessExecutionPolicy
  -> ObservationBundleId
  -> [TextProcessSubject a]
  -> [a]
  -> IO (ObservationBundle a Text.Text)
observeTextProcessesWithWorkers
  (WorkerCount workerCount)
  policy
  bundleId
  subjects
  inputs = do
    semaphore <- newQSem workerCount
    indexed <-
      mapConcurrently
        (observeIndexed semaphore)
        (zip [0 :: Int ..] tasks)
    let observations = map snd (sortOn fst indexed)
    pure
      ( mkObservationBundle
          bundleId
          (processExecutionPolicyId policy)
          observations
      )
  where
    tasks =
      [ (subject, input)
      | subject <- subjects
      , input <- inputs
      ]

    observeIndexed semaphore (index, (subject, input)) =
      bracket_
        (waitQSem semaphore)
        (signalQSem semaphore)
        (do
          outcome <- runTextSubject policy subject input
          pure
            ( index
            , Observation
                { observationSubject = textProcessSubjectId subject
                , observationInput = input
                , observationOutcome = outcome
                }
            )
        )
