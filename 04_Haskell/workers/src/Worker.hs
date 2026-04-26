{-# LANGUAGE ImportQualifiedPost #-}

module Worker
  ( Worker (..),
    newWorker,
    execute,
  )
where

import Behaviour (Behaviour (ExactlyOnce, HighPriority, LongRunning, RequiresAffinity, ResourceIntensive, Retryable))
import Control.Concurrent (threadDelay)
import Control.Concurrent.STM (TVar, atomically, modifyTVar', readTVar, readTVarIO)
import Control.Concurrent.STM.TBQueue (TBQueue, readTBQueue)
import Control.Exception (ErrorCall (ErrorCall), SomeException, throwIO, try)
import Control.Monad (forM_, unless, when)
import Data.Bits (xor)
import Data.Map.Strict qualified as Map
import Data.Set qualified as Set
import Data.Time.Clock (getCurrentTime)
import ExecutionModel (ExecutionModel (Actor, Batch, EventDriven, OneOff, Scheduled, Stream, Workflow))
import System.Random (randomRIO)
import Text.Printf (printf)
import Work (Work (behaviours, executionModel, workId))

newtype Worker = Worker
  { channel :: TBQueue (Maybe Work)
  }
  deriving (Eq)

newWorker :: TBQueue (Maybe Work) -> Worker
newWorker q = Worker {channel = q}

execute :: Worker -> TVar (Map.Map Int ()) -> TVar Bool -> IO ()
execute worker processed cancelled = do
  let loop = do
        isCancelled <- readTVarIO cancelled
        if isCancelled
          then return ()
          else do
            item <- atomically $ readTBQueue (channel worker)
            case item of
              Nothing -> return ()
              Just work -> do
                printf
                  "Working on item %d | Model=%s | Behaviour=%s\n"
                  (workId work)
                  (show $ executionModel work)
                  (show $ behaviours work)

                simulate work processed cancelled

                printf "Done work %d.\n" (workId work)

                loop

  loop

simulate :: Work -> TVar (Map.Map Int ()) -> TVar Bool -> IO ()
simulate work processed cancelled = do
  when (ExactlyOnce `Set.member` behaviours work) $ do
    inserted <- atomically $ do
      p <- readTVar processed
      if Map.member (workId work) p
        then return False
        else modifyTVar' processed (Map.insert (workId work) ()) >> return True

    unless inserted $ do
      printf "  [ExactlyOnce] Work %d already processed -> skipping.\n" (workId work)
      return ()

  let attempts = if Retryable `Set.member` behaviours work then 3 else 1

  forM_ [1 .. attempts] $ \attempt -> do
    isCancelled <- readTVarIO cancelled
    if isCancelled
      then printf "  Work cancelled\n"
      else do
        result <- try $ do
          when (HighPriority `Set.member` behaviours work) $
            printf "  [HighPriority] Fast-lane execution.\n"

          let lane = abs (workId work) `mod` 4
          when (RequiresAffinity `Set.member` behaviours work) $
            printf "  [RequiresAffinity] Routing to lane %d.\n" lane

          simulateByExecutionModel work lane cancelled

        case result of
          Right _ ->
            if Retryable `Set.member` behaviours work
              then printf "  [Retryable] Succeeded on attempt %d/%d.\n" attempt attempts
              else printf "  Completed.\n"
          Left ex -> do
            printf "  Attempt %d/%d failed: %s\n" attempt attempts (show (ex :: SomeException))
            if attempt == attempts
              then printf "  Giving up.\n"
              else do
                -- Tiny exponential-ish backoff for the demo.
                let backoffUs = 50000 * attempt * attempt
                threadDelay backoffUs

simulateByExecutionModel :: Work -> Int -> TVar Bool -> IO ()
simulateByExecutionModel work lane cancelled = do
  -- Base pacing. Behaviours can tweak it.
  let baseDelayUs = 80000

  stepDelayUs <-
    if LongRunning `Set.member` behaviours work
      then do
        printf "  [LongRunning] Slower steps.\n"
        return (baseDelayUs + 160000 :: Int)
      else return baseDelayUs

  when (ResourceIntensive `Set.member` behaviours work) $
    printf "  [ResourceIntensive] Adding CPU work.\n"

  -- Scheduled: pretend we had to wait until a trigger time.
  when (Scheduled == executionModel work) $ do
    printf "  [Scheduled] Waiting for trigger...\n"
    threadDelay 150000

  case executionModel work of
    OneOff -> step "OneOff: run once" stepDelayUs
    EventDriven -> step "EventDriven: handle event payload" stepDelayUs
    Batch -> do
      printf "  [Batch] Processing items...\n"
      forM_ [1 .. 5 :: Int] $ \i -> do
        step ("Batch item " ++ show i ++ "/5") stepDelayUs
    Stream -> do
      printf "  [Stream] Polling/consuming stream ticks...\n"
      forM_ [1 .. 4 :: Int] $ \tick -> do
        step ("Stream tick " ++ show tick ++ "/4") (stepDelayUs + 40000)
    Workflow -> do
      printf "  [Workflow] Running steps (DAG-ish)...\n"
      step "Step A: validate" stepDelayUs
      step "Step B: transform" (stepDelayUs + 20000)
      step "Step C: persist" (stepDelayUs + 40000)
    Actor -> do
      printf "  [Actor] Handling partition key lane=%d (stateful-ish)...\n" lane
      step "Actor turn: load state" stepDelayUs
      step "Actor turn: apply work" (stepDelayUs + 20000)
      step "Actor turn: save state" (stepDelayUs + 40000)
    Scheduled -> step "Scheduled: execute job" (stepDelayUs + 40000)
  where
    step label delayUs = do
      isCancelled <- readTVarIO cancelled
      if isCancelled
        then return ()
        else do
          printf "  -> %s (Id %d)\n" label (workId work)
          if ResourceIntensive `Set.member` behaviours work
            then do
              cpuBump 25000
              return ()
            else do
              maybeFailTransiently
              threadDelay delayUs
    -- ResourceIntensive: do a tiny CPU spin per step (demo only).
    cpuBump iterations = do
      _ <- getCurrentTime
      let loop 0 _ = return ()
          loop n x = loop (n - 1) ((x * 31) `xor` n)
      loop iterations (0 :: Int)
    -- Random transient failure for Retryable demos.
    maybeFailTransiently = do
      when (Retryable `Set.member` behaviours work) $ do
        -- Fail sometimes (more often when "resource intensive") so retries are visible.
        let odds = if ResourceIntensive `Set.member` behaviours work then 4 else 7 :: Int -- 1/4 or 1/7
        i <- randomRIO (0, odds)
        when (i == 0) $ throwIO (ErrorCall "Transient failure (simulated).")
