defmodule Domain.Request.InvalidPathError do
  # This should dissapear and we should use KeywordLens once we figure out the recursion
  # scheme for it.
  @moduledoc """
  We use this when traversing paths to values in a Domain.Request.
  """
  defexception [:message]
end
