{-# LANGUAGE ImportQualifiedPost #-}

module Work
  ( Work (..),
    createWork,
  )
where

import Behaviour (Behaviour, Behaviours, toBit)
import Control.Monad (filterM)
import Data.Bits ((.&.))
import Data.Set (Set)
import Data.Set qualified as Set
import ExecutionModel (ExecutionModel)
import System.Random (randomRIO)

data Work = Work
  { workId :: Int,
    executionModel :: ExecutionModel,
    behaviours :: Behaviours
  }
  deriving (Show, Eq)

createWork :: Int -> IO Work
createWork workId = do
  executionModel <- pickRandomExecutionModel
  behaviours <- pickRandomBehaviour
  return $
    Work
      { workId = workId,
        executionModel = executionModel,
        behaviours = behaviours
      }

allExecutionModels :: [ExecutionModel]
allExecutionModels = [minBound .. maxBound]

allBehaviours :: [Behaviour]
allBehaviours = [minBound .. maxBound]

pickRandomExecutionModel :: IO ExecutionModel
pickRandomExecutionModel = do
  i <- randomRIO (0, length allExecutionModels - 1)
  return $ allExecutionModels !! i

pickRandomBehaviour :: IO Behaviours
pickRandomBehaviour = do
  -- keep only atomic flags
  let singles = filter (isPowerOfTwo . toBit) allBehaviours
  -- for each flag, flip a coin, keep if randomRIO returns 0
  selected <- filterM (\_ -> (== 0) <$> randomRIO (0, 1 :: Int)) singles
  if null selected
    then do
      -- avoid empty set: pick one flag at random as fallback
      i <- randomRIO (0, length singles - 1)
      return $ Set.singleton (singles !! i)
    else
      -- wrap the selected flags in a Set
      return $ Set.fromList selected

isPowerOfTwo :: Int -> Bool
isPowerOfTwo n = n /= 0 && (n .&. (n - 1)) == 0
