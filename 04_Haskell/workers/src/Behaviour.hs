{-# LANGUAGE ImportQualifiedPost #-}

module Behaviour
  ( Behaviour (..),
    Behaviours,
    none,
    toBit,
  )
where

import Data.Set (Set)
import Data.Set qualified as Set

data Behaviour
  = None_
  | HighPriority
  | LongRunning
  | ResourceIntensive
  | RequiresAffinity
  | Retryable
  | ExactlyOnce
  deriving (Show, Eq, Ord, Enum, Bounded)

type Behaviours = Set Behaviour

none :: Behaviours
none = Set.empty

toBit :: Behaviour -> Int
toBit None_ = 0
toBit HighPriority = 1
toBit LongRunning = 2
toBit ResourceIntensive = 4
toBit RequiresAffinity = 8
toBit Retryable = 16
toBit ExactlyOnce = 32