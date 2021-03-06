-- |
module Data.Metrics.Snapshot (
  Snapshot(..),
  quantile,
  size,
  median,
  get75thPercentile,
  get95thPercentile,
  get98thPercentile,
  get99thPercentile,
  get999thPercentile,
  takeSnapshot
) where
import Control.Monad.Primitive
import Data.Primitive.MutVar
import Data.Vector.Algorithms.Intro
import qualified Data.Vector.Unboxed as I
import qualified Data.Vector.Unboxed.Mutable as V

-- | A wrapper around a *sorted* vector intended for calculating quantile statistics.
newtype Snapshot = Snapshot
  { fromSnapshot :: I.Vector Double -- ^ A sorted "Vector" of samples.
  }
  deriving (Show)

medianQ :: Double
medianQ = 0.5

p75Q :: Double
p75Q = 0.75

p95Q :: Double
p95Q = 0.95

p98Q :: Double
p98Q = 0.98

p99Q :: Double
p99Q = 0.99

p999Q :: Double
p999Q = 0.999

clamp :: Double -> Double
clamp x = if x > 1
  then 1
  else if x < 0
    then 0
    else x

-- | A utility function for snapshotting data from an unsorted "MVector" of samples.
--
-- NB: this function uses "unsafeFreeze" under the hood, so be sure that the vector being
-- snapshotted is not used after calling this function.
takeSnapshot :: PrimMonad m => V.MVector (PrimState m) Double -> m Snapshot
takeSnapshot v = V.clone v >>= \v' -> sort v' >> I.unsafeFreeze v' >>= return . Snapshot

-- | Calculate an arbitrary quantile value for a "Snapshot".
-- Values below zero or greater than one will be clamped to the range [0, 1]
quantile :: Double -> Snapshot -> Double
quantile quantile (Snapshot s) = if pos > fromIntegral (I.length s)
  then I.last s
  else if pos' < 1
    then I.head s
    else lower + (pos - fromIntegral (floor pos :: Int)) * (upper - lower)
  where
    q = clamp quantile
    pos = q * (1 + (fromIntegral $ I.length s))
    pos' = truncate pos
    lower = I.unsafeIndex s (pos' - 1)
    upper = I.unsafeIndex s pos'

-- | Get the number of elements in a "Snapshot"
size :: Snapshot -> Int
size (Snapshot s) = I.length s

-- | Calculate the median value of a "Snapshot"
median :: Snapshot -> Double
median = quantile medianQ

-- | Calculate the 75th percentile of a "Snapshot"
get75thPercentile :: Snapshot -> Double
get75thPercentile = quantile p75Q

-- | Calculate the 95th percentile of a "Snapshot"
get95thPercentile :: Snapshot -> Double
get95thPercentile = quantile p95Q

-- | Calculate the 98th percentile of a "Snapshot"
get98thPercentile :: Snapshot -> Double
get98thPercentile = quantile p98Q

-- | Calculate the 99th percentile of a "Snapshot"
get99thPercentile :: Snapshot -> Double
get99thPercentile = quantile p99Q

-- | Calculate the 99.9th percentile of a "Snapshot"
get999thPercentile :: Snapshot -> Double
get999thPercentile = quantile p999Q

