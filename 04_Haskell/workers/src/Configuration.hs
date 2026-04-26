module Configuration
  ( Configuration (..),
    fromArgs,
  )
where

import Text.Read (readMaybe)

data Configuration = Configuration
  { messageCount :: Int,
    threadCount :: Int
  }
  deriving (Show, Eq)

fromArgs :: [String] -> Either String Configuration
fromArgs args
  | length args < 4 = Left "Invalid input. Pass required arguments: '--message-count', '--thread-count'."
  | otherwise = parse args (Configuration 0 0)

parse :: [String] -> Configuration -> Either String Configuration
parse [] cfg
  | messageCount cfg > 0 && threadCount cfg > 0 = Right cfg
  | otherwise = Left "Invalid input. Pass required arguments: '--message-count', '--thread-count'."
parse ("--message-count" : n : rest) cfg =
  case readMaybe n of
    Nothing -> Left $ "Invalid value for --message-count: " ++ n
    Just v -> parse rest cfg {messageCount = v}
parse ("--thread-count" : n : rest) cfg =
  case readMaybe n of
    Nothing -> Left $ "Invalid value for --thread-count: " ++ n
    Just v -> parse rest cfg {threadCount = v}
parse (_ : rest) cfg = parse rest cfg