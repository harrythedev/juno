{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE LambdaCase #-}

module Juno.Monitoring.Server
  ( startMonitoring
  ) where

import Juno.Runtime.Types (Config, Metric(..), LogIndex(..), Term(..), nodeId,
                           _port)

import System.Remote.Monitoring (Server, forkServer, getLabel, getGauge)
import Control.Lens ((^.), to)

import qualified Data.Text as T
import qualified System.Metrics.Label as Label
import qualified System.Metrics.Gauge as Gauge

-- TODO: probably switch to 'newStore' API. this allows us to use groups.

startApi :: Config -> IO Server
startApi config = forkServer "localhost" port
  where
    -- TODO: change this port / load it from config
    port = 80 + fromIntegral (config ^. nodeId . to _port)

startMonitoring :: Config -> IO (Metric -> IO ())
startMonitoring config = do
  ekg <- startApi config

  -- Consensus
  termGauge <- getGauge "juno.consensus.term" ekg
  logIndexGauge <- getGauge "juno.consensus.log_index" ekg
  commitIndexGauge <- getGauge "juno.consensus.commit_index" ekg
  -- Node
  roleLabel <- getLabel "juno.node.role" ekg
  appliedIndexGauge <- getGauge "juno.node.applied_index" ekg

  return $ \case
    -- Consensus
    MetricTerm (Term t) ->
      Gauge.set termGauge $ fromIntegral t
    MetricLogIndex (LogIndex idx) ->
      Gauge.set logIndexGauge $ fromIntegral idx
    MetricCommitIndex (LogIndex idx) ->
      Gauge.set commitIndexGauge $ fromIntegral idx
    -- Node
    MetricRole role ->
       Label.set roleLabel $ T.pack $ show role
    MetricAppliedIndex (LogIndex idx) ->
      Gauge.set appliedIndexGauge $ fromIntegral idx
