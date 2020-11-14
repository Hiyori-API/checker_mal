defmodule CheckerMal.Core.Scheduler do
  @moduledoc """
  Periodically checks the config/postgres db
  Based on when those page ranges were last run,
  decides when to request how many pages from MAL
  """

  # TODO: implement handle_cast which receives a page number from index
  # if a page range exceeded past what it was supposed to check, it can
  # mark other page ranges as newly checked as well
end
