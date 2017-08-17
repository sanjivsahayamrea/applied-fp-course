{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module FirstApp.AppM where

import           Control.Monad.IO.Class (MonadIO)
import           Control.Monad.Reader   (MonadReader, ReaderT, runReaderT)

import           Data.Text              (Text)

import           FirstApp.Conf          (Conf)
import           FirstApp.DB            (FirstAppDB)

-- One motivation for using ReaderT is that there exists some information in
-- your application that is used almost everywhere and it is tiresome to have to
-- weave it through everywhere. We also don't allow "global variables" as they
-- are error prone, fragile, and prevent you from properly being able to reason
-- about the operation of your program.
--
-- a ReaderT is a function from some 'r' to some 'm a' : (r -> m a). Where by
-- the 'r' is accessible to all functions that run in the context of that 'm'.
--
-- This means that if you use the 'r' everywhere or simply enough throughout
-- your application, you no longer have to constantly weave the extra 'r' as an
-- argument to everything that might need it.
-- Since by definition:
-- foo :: ReaderT r m a
-- When run, becomes:
-- foo :: r -> m a
--
-- First, let's clean up our (Conf,FirstAppDB) with an application Env type. We
-- will add a general purpose logging function, since we're not limited to
-- just values!
data Env = Env
  -- Add the type signature of a very general "logging" function.
  { loggingRick :: Text -> AppM ()
  , envConfig   :: Conf
  , envDb       :: FirstAppDB
  }

-- Lets crack on and define a newtype wrapper for our ReaderT, this will save us
-- having to write out the full ReaderT definition for every function that uses it.
newtype AppM a = AppM
  -- Our ReaderT will only contain the Env, and our base monad will be IO, leave
  -- the return type polymorphic so that it will work regardless of what is
  -- being returned from the functions that will use it. Using a newtype (in
  -- addition to the useful type system) means that it is harder to use a
  -- different ReaderT when we meant to use our own, or vice versa. In such a
  -- situation it is extremely unlikely the application would compile at all,
  -- but the name differences alone make the confusion a little less likely.
  { unAppM :: ReaderT Env IO a }
  -- Because we're using a newtype, all of the instance definitions for ReaderT
  -- would normally no apply. However, because we've done nothing but create a
  -- convenience wrapper for our ReaderT, there is an extension for Haskell that
  -- allows it to simply extend all the existing instances to work without AppM.
  -- Add the GeneralizedNewtypeDeriving pragma to the top of the file and these
  -- all work without any extra effort.
  deriving ( Functor
           , Applicative
           , Monad
           , MonadReader Env
           , MonadIO
           )

-- This a helper function that will take the requirements for our ReaderT, an
-- Env, and the (AppM a) that is the context/action to be run with the given Env.
--
-- First step is to unwrap our AppM, the newtype definition we wrote gives us
-- that function:
-- unAppM :: AppM a -> ReaderT Env IO a
--
-- Then we run the ReaderT, which itself is just a newtype to get access to the
-- action we're going to evaluate:
-- runReaderT :: ReaderT r m a -> r -> m a
-- ~
-- runReaderT :: ReaderT Env IO a -> Env -> IO a
--
-- Combining them (runReaderT . unAppM) we are left with:
-- Env -> IO a
--
-- We have an Env so that leaves us with the:
-- IO a
-- and we're done.
runAppM
  :: Env
  -> AppM a
  -> IO a
runAppM env appM =
  runReaderT (unAppM appM) env

