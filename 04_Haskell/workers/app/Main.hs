{-# LANGUAGE ImportQualifiedPost #-}

import Configuration (Configuration (messageCount, threadCount), fromArgs)
import Control.Concurrent.Async (mapConcurrently_)
import Control.Concurrent.STM (atomically, newTVarIO, writeTVar)
import Control.Concurrent.STM.TBQueue (newTBQueue, writeTBQueue)
import Control.Exception (AsyncException (UserInterrupt), catch)
import Control.Monad (forM_)
import Data.Map.Strict qualified as Map
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)
import Text.Printf (printf)
import Work (createWork)
import Worker (execute, newWorker)

main :: IO ()
main = do
  -- shared cancellation flag, equivalent to CancellationTokenSource
  cancelled <- newTVarIO False

  let run = do
        args <- getArgs
        cfg <- case fromArgs args of
          Left err -> hPutStrLn stderr err >> exitFailure
          Right cfg -> return cfg

        printf "\nValid configuration received. Starting...\n"

        -- add threadCount to fit all work items plus one Nothing sentinel per worker
        channel <- atomically $ newTBQueue (fromIntegral $ messageCount cfg + threadCount cfg)

        -- produce: fill the queue with work
        forM_ [1 .. messageCount cfg] $ \i -> do
          work <- createWork i
          atomically $ writeTBQueue channel (Just work)

        -- signal completion: one Nothing per worker, each worker stops on its own sentinel
        forM_ [1 .. threadCount cfg] $ \_ ->
          atomically $ writeTBQueue channel Nothing
        
        processed <- newTVarIO (Map.empty :: Map.Map Int ())

        -- spawn threadCount workers concurrently, wait for all to finish (equivalent to Task.WhenAll)
        let workers = replicate (threadCount cfg) (newWorker channel)
        mapConcurrently_ (\w -> execute w processed cancelled) workers

        printf "Work completed. Shutting down...\n"

  -- catch async exceptions on the main thread
  -- GHC delivers Ctrl+C as UserInterrupt to the main thread, equivalent to CancelKeyPress
  run `catch` \e -> case (e :: AsyncException) of
    UserInterrupt -> atomically $ writeTVar cancelled True
    _ -> return ()