{-# LANGUAGE OverloadedStrings #-}

module MetaTest.CI
  ( LaneLevel (..)
  , CILane (..)
  , CIManifest (..)
  , CIReceipt (..)
  , ReceiptOutcome (..)
  , loadCIManifest
  , validateCIManifest
  , findCILane
  , runCILane
  , runCILaneFrom
  , writeCIReceipt
  , printOutcome
  , exitCodeForOutcome
  ) where

import Data.Aeson
  ( FromJSON (..)
  , ToJSON (..)
  , eitherDecode
  , encode
  , object
  , withObject
  , withText
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.List (nub)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import MetaTest.Core
  ( ExecutionPolicyId (..)
  , SubjectId (..)
  )
import MetaTest.Execution
  ( ProcessExecutionPolicy (..)
  , ProcessOutput (..)
  , mkTextProcessSubject
  , runTextSubjectCaptured
  )
import MetaTest.Outcome
  ( ExceptionInfo (..)
  , ExitInfo (..)
  , Outcome (..)
  , ResourceLimitInfo (..)
  , SpawnFailureInfo (..)
  , TimeoutInfo (..)
  )
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Exit (ExitCode (..))
import System.FilePath
  ( (</>)
  , isAbsolute
  , normalise
  , splitDirectories
  , takeDirectory
  )
import System.IO (stderr)

data LaneLevel
  = ExecutionLevel
  | DiscriminationLevel
  deriving (Eq, Ord, Show)

instance FromJSON LaneLevel where
  parseJSON =
    withText "LaneLevel" $ \value ->
      case value of
        "execution" -> pure ExecutionLevel
        "discrimination" -> pure DiscriminationLevel
        other -> fail ("unknown MetaTest CI level: " ++ Text.unpack other)

instance ToJSON LaneLevel where
  toJSON level =
    toJSON $
      case level of
        ExecutionLevel -> ("execution" :: Text)
        DiscriminationLevel -> "discrimination"

data CILane = CILane
  { ciLaneId :: Text
  , ciLaneLevel :: LaneLevel
  , ciLaneCommand :: [Text]
  , ciLaneTimeoutSeconds :: Int
  , ciLaneWorkingDirectory :: Maybe FilePath
  }
  deriving (Eq, Show)

instance FromJSON CILane where
  parseJSON =
    withObject "CILane" $ \obj ->
      CILane
        <$> obj .: "id"
        <*> obj .: "level"
        <*> obj .: "command"
        <*> obj .:? "timeout_seconds" .!= 900
        <*> obj .:? "working_directory"

data CIManifest = CIManifest
  { ciManifestSchema :: Text
  , ciManifestRepository :: Text
  , ciManifestLanes :: [CILane]
  }
  deriving (Eq, Show)

instance FromJSON CIManifest where
  parseJSON =
    withObject "CIManifest" $ \obj ->
      CIManifest
        <$> obj .: "schema"
        <*> obj .: "repository"
        <*> obj .: "lanes"

data ReceiptOutcome
  = ReceiptReturned
  | ReceiptExited Int
  | ReceiptTimedOut
  | ReceiptSpawnFailed Text
  | ReceiptResourceLimited Text
  | ReceiptRaised Text
  deriving (Eq, Show)

instance ToJSON ReceiptOutcome where
  toJSON outcome =
    case outcome of
      ReceiptReturned ->
        object ["tag" .= ("returned" :: Text)]
      ReceiptExited code ->
        object
          [ "tag" .= ("exited" :: Text)
          , "code" .= code
          ]
      ReceiptTimedOut ->
        object ["tag" .= ("timed_out" :: Text)]
      ReceiptSpawnFailed detail ->
        object
          [ "tag" .= ("spawn_failed" :: Text)
          , "detail" .= detail
          ]
      ReceiptResourceLimited detail ->
        object
          [ "tag" .= ("resource_limited" :: Text)
          , "detail" .= detail
          ]
      ReceiptRaised detail ->
        object
          [ "tag" .= ("raised" :: Text)
          , "detail" .= detail
          ]

data CIReceipt = CIReceipt
  { ciReceiptSchema :: Text
  , ciReceiptRepository :: Text
  , ciReceiptLane :: Text
  , ciReceiptLevel :: LaneLevel
  , ciReceiptCommand :: [Text]
  , ciReceiptTimeoutSeconds :: Int
  , ciReceiptWorkingDirectory :: Maybe FilePath
  , ciReceiptToolRevision :: Maybe Text
  , ciReceiptCallerSha :: Maybe Text
  , ciReceiptOutcome :: ReceiptOutcome
  }
  deriving (Eq, Show)

instance ToJSON CIReceipt where
  toJSON receipt =
    object
      [ "schema" .= ciReceiptSchema receipt
      , "repository" .= ciReceiptRepository receipt
      , "lane" .= ciReceiptLane receipt
      , "level" .= ciReceiptLevel receipt
      , "command" .= ciReceiptCommand receipt
      , "timeout_seconds" .= ciReceiptTimeoutSeconds receipt
      , "working_directory" .= ciReceiptWorkingDirectory receipt
      , "metatest_tool_revision" .= ciReceiptToolRevision receipt
      , "caller_sha" .= ciReceiptCallerSha receipt
      , "outcome" .= ciReceiptOutcome receipt
      ]

loadCIManifest :: FilePath -> IO (Either String CIManifest)
loadCIManifest path = do
  content <- BL.readFile path
  pure $ do
    manifest <- eitherDecode content
    validateCIManifest manifest
    pure manifest

validateCIManifest :: CIManifest -> Either String ()
validateCIManifest manifest
  | ciManifestSchema manifest /= "metatest-ci/v1" =
      Left "schema must be metatest-ci/v1"
  | Text.null (Text.strip (ciManifestRepository manifest)) =
      Left "repository is required"
  | null lanes =
      Left "at least one CI lane is required"
  | length laneIds /= length (nub laneIds) =
      Left "CI lane ids must be unique"
  | otherwise =
      traverse_ validateLane lanes
  where
    lanes = ciManifestLanes manifest
    laneIds = map ciLaneId lanes

validateLane :: CILane -> Either String ()
validateLane lane
  | Text.null (Text.strip (ciLaneId lane)) =
      Left "CI lane id is required"
  | ciLaneTimeoutSeconds lane <= 0 || ciLaneTimeoutSeconds lane > 86400 =
      Left ("lane " ++ laneName ++ ": timeout_seconds must be in 1..86400")
  | otherwise =
      case ciLaneCommand lane of
        [] ->
          Left ("lane " ++ laneName ++ ": command must be non-empty")
        executable : _
          | Text.null (Text.strip executable) ->
              Left ("lane " ++ laneName ++ ": executable must be non-empty")
          | otherwise ->
              validateWorkingDirectory
  where
    laneName = Text.unpack (ciLaneId lane)

    validateWorkingDirectory =
      case ciLaneWorkingDirectory lane of
        Nothing -> Right ()
        Just dir
          | isAbsolute dir ->
              Left ("lane " ++ laneName ++ ": working_directory must be repository-relative")
          | ".." `elem` splitDirectories dir ->
              Left ("lane " ++ laneName ++ ": working_directory must not escape the repository")
          | otherwise -> Right ()

findCILane :: Text -> CIManifest -> Either String CILane
findCILane laneId manifest =
  case filter ((== laneId) . ciLaneId) (ciManifestLanes manifest) of
    [lane] -> Right lane
    [] -> Left ("unknown MetaTest CI lane: " ++ Text.unpack laneId)
    _ -> Left ("duplicate MetaTest CI lane: " ++ Text.unpack laneId)

runCILane
  :: CIManifest
  -> CILane
  -> IO (CIReceipt, Outcome ProcessOutput, ExitCode)
runCILane = runCILaneFrom "."

runCILaneFrom
  :: FilePath
  -> CIManifest
  -> CILane
  -> IO (CIReceipt, Outcome ProcessOutput, ExitCode)
runCILaneFrom repositoryRoot manifest lane =
  case ciLaneCommand lane of
    [] -> error "validated MetaTest CI lane unexpectedly has an empty command"
    executable : arguments -> do
      let policy =
            ProcessExecutionPolicy
              { processExecutionPolicyId =
                  ExecutionPolicyId ("metatest-ci:" <> ciLaneId lane <> ":v1")
              , processTimeoutMicros = ciLaneTimeoutSeconds lane * 1000000
              }
          subject =
            mkTextProcessSubject
              (SubjectId ("ci/" <> ciLaneId lane))
              (Text.unpack executable)
              (const (map Text.unpack arguments))
              ( Just
                  ( normalise
                      ( repositoryRoot
                          </> maybe "." id (ciLaneWorkingDirectory lane)
                      )
                  )
              )
      outcome <- runTextSubjectCaptured policy subject ()
      toolRevision <- fmap Text.pack <$> lookupEnv "METATEST_TOOL_REVISION"
      callerSha <- fmap Text.pack <$> lookupEnv "GITHUB_SHA"
      let receipt =
            CIReceipt
              { ciReceiptSchema = "metatest-ci-receipt/v1"
              , ciReceiptRepository = ciManifestRepository manifest
              , ciReceiptLane = ciLaneId lane
              , ciReceiptLevel = ciLaneLevel lane
              , ciReceiptCommand = ciLaneCommand lane
              , ciReceiptTimeoutSeconds = ciLaneTimeoutSeconds lane
              , ciReceiptWorkingDirectory = ciLaneWorkingDirectory lane
              , ciReceiptToolRevision = toolRevision
              , ciReceiptCallerSha = callerSha
              , ciReceiptOutcome = receiptOutcome outcome
              }
      pure (receipt, outcome, exitCodeForOutcome outcome)

receiptOutcome :: Outcome ProcessOutput -> ReceiptOutcome
receiptOutcome outcome =
  case outcome of
    Returned _ -> ReceiptReturned
    Exited ExitInfo {exitCode = code} -> ReceiptExited code
    TimedOut _ -> ReceiptTimedOut
    SpawnFailed SpawnFailureInfo {spawnFailureMessage = detail} ->
      ReceiptSpawnFailed detail
    ResourceLimited ResourceLimitInfo {resourceLimitLabel = detail} ->
      ReceiptResourceLimited detail
    Raised ExceptionInfo {exceptionMessage = detail} ->
      ReceiptRaised detail

exitCodeForOutcome :: Outcome ProcessOutput -> ExitCode
exitCodeForOutcome outcome =
  case outcome of
    Returned _ -> ExitSuccess
    Exited ExitInfo {exitCode = code} ->
      ExitFailure (normalizeExitCode code)
    TimedOut _ -> ExitFailure 124
    SpawnFailed _ -> ExitFailure 127
    ResourceLimited _ -> ExitFailure 125
    Raised _ -> ExitFailure 126

normalizeExitCode :: Int -> Int
normalizeExitCode code
  | code >= 1 && code <= 255 = code
  | otherwise = 1

writeCIReceipt :: FilePath -> CIReceipt -> IO ()
writeCIReceipt path receipt = do
  let parent = takeDirectory path
  createDirectoryIfMissing True parent
  BL.writeFile path (encode receipt)

printOutcome :: Outcome ProcessOutput -> IO ()
printOutcome outcome =
  case outcome of
    Returned ProcessOutput {processStdout = stdoutText, processStderr = stderrText} -> do
      TextIO.putStr stdoutText
      TextIO.hPutStr stderr stderrText
    Exited ExitInfo {exitStdout = stdoutText, exitStderr = stderrText} -> do
      TextIO.putStr stdoutText
      TextIO.hPutStr stderr stderrText
    TimedOut TimeoutInfo {timeoutLabel = detail} ->
      TextIO.hPutStrLn stderr ("MetaTest CI timeout: " <> detail)
    SpawnFailed SpawnFailureInfo {spawnFailureMessage = detail} ->
      TextIO.hPutStrLn stderr ("MetaTest CI spawn failure: " <> detail)
    ResourceLimited ResourceLimitInfo {resourceLimitLabel = detail} ->
      TextIO.hPutStrLn stderr ("MetaTest CI resource limit: " <> detail)
    Raised ExceptionInfo {exceptionMessage = detail} ->
      TextIO.hPutStrLn stderr ("MetaTest CI subject exception: " <> detail)

traverse_ :: (a -> Either String ()) -> [a] -> Either String ()
traverse_ _ [] = Right ()
traverse_ f (x : xs) = f x >> traverse_ f xs
