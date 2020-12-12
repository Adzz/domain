defmodule Domain.Validate do
  alias Domain.Request
  alias Jbt.DateUtils

  @moduledoc """
  This module is full of wonderful validations you may wish to apply to incoming domain request
  state. This gives us a place to apply validations / alterations that apply across contexts.

  For example, we may wish to always validate that start_date is never after end_date, instead of
  repeating that everywhere, we can make a request. Ensure that request gets piped through the
  start_date_not_after_end_date validation, and away we go!

  All of the functions in here should take in a Request and should return one or an error tuple.
  The functions in here should not add to the Request state like a step would, but usually just
  validate a value within it.
  """

  @doc """
  Check that all of the given keys in state point to something that looks like a ULID,
  - which is what we currently use as primary keys in the DB.
  """
  def id_looks_right(request = %Request{}, keys) do
    # validate(request, fn state ->
    #   Enum.reduce_while(keys, [], fn key, _ ->
    #     case Ecto.ULID.dump(Map.get(state, key)) do
    #       {:ok, _} -> {:cont, {:ok, request}}
    #       :error -> {:halt, {:error, "Not a valid Id"}}
    #     end
    #   end)
    # end)
    request
  end

  @doc """
  Passes the request state to the given validation function and calls it. If the validation_fun
  returns an okay tuple, we return the request, otherwise we return the error tuple.

  The validation_fun is expected to return {:ok, term } | {:error term}
  """
  # Now all of the functions in this module can be implemented with this. And users can define
  # their own validation funs that don't interact with the Request at all. Which is of course the
  # point.

  # Really this should also abstract the traversal and application of the validation. So that the
  # validations you write can be automatically applied to each field described by the keyword lens.
  def validate(request, validation_fun) do
    case validation_fun.(request.state) do
      {:ok, _} -> {:ok, request}
      error = {:error, _} -> error
    end
  end

  @doc """
  Checks function state to ensure that all of the provided keys point to something that is not nil.
  Raises if given a key that is not in function state.
  """
  def not_nil(request, keys) do
    # validate(request, fn state ->
    #   Enum.reduce_while(keys, [], fn key, _ ->
    #     case Map.fetch!(state, key) do
    #       nil -> {:halt, {:error, "#{key} not found"}}
    #       _ -> {:cont, {:ok, request}}
    #     end
    #   end)
    # end)
    request
  end

  @doc """
  Fails if the date is not a valid date. Now the user needs to pass in their own validation funs.
  """
  # Probably an optional error message is a good idea.
  def date_is_a_date(request = %Request{}, keys \\ [:date]) do
    # validate(request, fn state ->
    #   Enum.reduce_while(keys, [], fn key, _ ->
    #     case Map.fetch!(state, key) |> DateUtils.is_valid?() do
    #       true -> {:cont, {:ok, request}}
    #       false -> {:halt, {:error, "Date is not a valid date!"}}
    #     end
    #   end)
    # end)
    request
  end

  @doc """
  Ensures all of the values pointed to by the keys are >= 0. Does no coercion of types, so if you
  put shit in you will get shit out. Erlang term ordering will give you an answer, but like
  nil > 0 is true...

  If we do type coercion I think we basically re-invent changesets.
  Also if we are doing it we should really do it and allow nested stuffs, with lenses like the
  parse_decimal thing.
  """
  def not_negative(request = %Request{}, keys, error_message \\ "Number can't be negative") do
    # validate(request, fn state ->
    #   Enum.reduce_while(keys, [], fn key, _ ->
    #     # No type coercion...fine for now.
    #     case Map.fetch!(state, key) >= 0 do
    #       true -> {:cont, {:ok, request}}
    #       false -> {:halt, {:error, error_message}}
    #     end
    #   end)
    # end)
    request
  end
end
