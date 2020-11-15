defmodule CheckerMal.Core.Test do
  use ExUnit.Case, async: true

  doctest CheckerMal.Core.Parser
  doctest CheckerMal.Core.Scheduler.Config

end
