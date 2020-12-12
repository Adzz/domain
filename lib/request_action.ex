defmodule Domain.RequestAction do
  @moduledoc """
  A RequestAction is a function that takes in a Domain.Request and returns a Domain.Request
  altering the state or the steps in the Request in some way. This may be contrasted to a Validation
  which does not alter the Request in anyway, but validates whether it should continue.
  """

  alias Domain.Request
  alias Jbt.DateUtils

  @doc """
  Merges the given function state into the existing ones.
  """
  def merge_request_state(request = %Domain.Request{}, state = %{}) do
    state = Map.merge(request.state, state)
    {:ok, %{request | state: state}}
  end

  @doc """
  Changes the date in the state pointed at by the date_key to be the date of Monday of that
  week.
  """
  def coerce_date_to_monday(request = %Request{}, date_key \\ :start_date) do
    start_date = Map.fetch!(request.state, date_key)
    merge_request_state(request, %{date_key => DateUtils.beginning_of_week(start_date)})
  end

  @doc """
  Inspects the request. Is useful as a step to trace the result so far

  ### Example

      iex>  req = Jbt.Domain.new_request(%{hi: :there})
      ...> Domain.Request.fail_fast(Domain.Request.add_step(req, &Domain.RequestAction.inspect/1))
      %Domain.Request{state: %{hi: :there}, on_error: &Jbt.Domain.handle_error/1, steps: [%Domain.Request.Step{action: &Domain.RequestAction.inspect/1, on_error: &Jbt.Domain.handle_error/1}]}
  """
  def inspect(req, label \\ ""), do: {:ok, req |> IO.inspect(limit: :infinity, label: label)}

  @doc """
  Adds something to function state under the given key by calling the provided fun. The provided
  fun will receive the request, and should return either an okay tuple with a new request in it
  or an error tuple. If an error tuple is returned the Request will return with that error.
  """
  def add_to_state(request, key, fun) do
    with {:ok, result} <- fun.(request.state) do
      merge_request_state(request, %{key => result})
    end
  end

  @doc """
  Will parse the list of keys in state as a decimal. If anyone of them fails to parse we return an
  error. Allows nested data IFF the data is a map

      iex> parse_as_decimal(Jbt.Domain.new_request(%{price: "1.20"}), [:price])
      {:ok, %Domain.Request{state: %{price: Decimal.new("1.20")}, steps: [], on_error: &Jbt.Domain.handle_error/1}}

      iex> parse_as_decimal(Jbt.Domain.new_request(%{price: "1.20"}), [:price])
      {:ok, %Domain.Request{state: %{price: Decimal.new("1.20")}, steps: [], on_error: &Jbt.Domain.handle_error/1}}

      iex> parse_as_decimal(Jbt.Domain.new_request(%{price: "ab1.20"}), [:price])
      {:error, "price could not be parsed as a number."}
  """
  def parse_as_decimal(request, keys, message \\ "could not be parsed as a number.") do
    Enum.reduce_while(keys, request, fn key, request_acc ->
      lens = to_lens(key, [:state])

      case get_in(request_acc, lens) |> Decimal.parse() do
        :error -> {:halt, {:error, "#{Enum.at(lens, -1)} " <> message}}
        {decimal, _truncated} -> {:cont, put_in(request_acc, lens, decimal)}
      end
    end)
    |> case do
      e = {:error, _} -> e
      req = %Domain.Request{} -> {:ok, req}
    end
  end

  defp to_lens({key, value}, acc) when is_atom(value) or is_binary(value), do: acc ++ [key, value]
  defp to_lens({key, value}, acc) when is_list(value), do: to_lens(value, acc ++ [key])
  defp to_lens([{key, value}], acc) when is_list(value), do: to_lens(value, acc ++ [key])
  defp to_lens(key, acc) when is_atom(key) or is_binary(key), do: acc ++ [key]

  defp to_lens([{key, value}], acc) when is_atom(value) or is_binary(value) do
    acc ++ [key, value]
  end

  defp to_lens(_, _) do
    raise Domain.Request.InvalidPathError,
          "Path is not in a recognized format. The paths should be " <>
            "a list of paths. So this is allowed:\n\n[a: [b: :c], a: [b: :d]]" <>
            "\n\nbut this is not:\n\n[a: [b: [:c, :d]]]"
  end

  @doc """
  Essentially unwraps the state in the Domain struct, passes them to a function and puts the
  result of calling that function back into the Domain Request. This means we don't have to have
  a bunch of domain structs know about the domain struct, and we can run side-effecty stuff.

  If the fun returns an error tuple we return that. If it returns an okay tuple the result is put
  into the request state.
  """
  def run(request, fun, result_key \\ :result) do
    with {:ok, result} <- fun.(request.state) do
      merge_request_state(request, %{result_key => result})
    end
  end
end
