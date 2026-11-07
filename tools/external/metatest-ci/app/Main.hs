module Main (main) where

import qualified Data.Text as Text
import MetaTest.CI
import System.Environment (getArgs)
import System.FilePath (takeDirectory)
import System.Exit
  ( die
  , exitWith
  )

main :: IO ()
main = do
  args <- getArgs
  case args of
    ["validate-manifest", manifestPath] -> do
      manifestResult <- loadCIManifest manifestPath
      case manifestResult of
        Left err -> die ("MetaTest CI manifest invalid: " ++ err)
        Right manifest ->
          putStrLn
            ( "MetaTest CI manifest valid: "
                ++ Text.unpack (ciManifestRepository manifest)
                ++ " ("
                ++ show (length (ciManifestLanes manifest))
                ++ " lanes)"
            )
    ["list-lanes", manifestPath] -> do
      manifest <- requireManifest manifestPath
      mapM_
        (\lane ->
          putStrLn
            ( Text.unpack (ciLaneId lane)
                ++ "\t"
                ++ show (ciLaneLevel lane)
            )
        )
        (ciManifestLanes manifest)
    "run-manifest" : rest -> runManifestCommand rest
    _ -> die usage

runManifestCommand :: [String] -> IO ()
runManifestCommand args = do
  options <- parseRunOptions args
  manifest <- requireManifest (runManifestPath options)
  lane <-
    case findCILane (Text.pack (runLaneId options)) manifest of
      Left err -> die err
      Right found -> pure found
  let receiptPath =
        case runReceiptPath options of
          Just path -> path
          Nothing ->
            ".metatest/receipts/"
              ++ sanitize (runLaneId options)
              ++ ".json"
  (receipt, outcome, resultCode) <-
    runCILaneFrom (takeDirectory (runManifestPath options)) manifest lane
  printOutcome outcome
  writeCIReceipt receiptPath receipt
  putStrLn
    ( "MetaTest CI receipt: "
        ++ receiptPath
        ++ " ["
        ++ runLaneId options
        ++ "]"
    )
  exitWith resultCode

requireManifest :: FilePath -> IO CIManifest
requireManifest path = do
  result <- loadCIManifest path
  case result of
    Left err -> die ("MetaTest CI manifest invalid: " ++ err)
    Right manifest -> pure manifest

data RunOptions = RunOptions
  { runManifestPath :: FilePath
  , runLaneId :: String
  , runReceiptPath :: Maybe FilePath
  }

parseRunOptions :: [String] -> IO RunOptions
parseRunOptions = go Nothing Nothing Nothing
  where
    go manifest lane receipt remaining =
      case remaining of
        [] ->
          case (manifest, lane) of
            (Just manifestPath, Just laneId) ->
              pure
                RunOptions
                  { runManifestPath = manifestPath
                  , runLaneId = laneId
                  , runReceiptPath = receipt
                  }
            _ -> die usage
        "--manifest" : path : xs -> go (Just path) lane receipt xs
        "--lane" : laneId : xs -> go manifest (Just laneId) receipt xs
        "--receipt" : path : xs -> go manifest lane (Just path) xs
        _ -> die usage

sanitize :: String -> String
sanitize = map replace
  where
    replace c
      | c >= 'a' && c <= 'z' = c
      | c >= 'A' && c <= 'Z' = c
      | c >= '0' && c <= '9' = c
      | c == '-' || c == '_' = c
      | otherwise = '_'

usage :: String
usage =
  unlines
    [ "usage:"
    , "  metatest-ci validate-manifest PATH"
    , "  metatest-ci list-lanes PATH"
    , "  metatest-ci run-manifest --manifest PATH --lane ID [--receipt PATH]"
    ]
