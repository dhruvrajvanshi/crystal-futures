require "./futures/*"
require "crz"
module Futures
  include CRZ::Monad::Macros
end