defmodule Domain.Request do
  @moduledoc """
  A struct to standardize the Domain Request format. This allows us to run a pipeline of
  steps on any incoming Domain request, creating composeable operations we can share between
  requests.
  """
  defmodule Step do
    @moduledoc """
    A type to encapsulate a step in the request. A step is usually a RequestValidation or a
    RequestAction and each step can have its own on_error callback.
    """
    @enforce_keys [:action, :on_error]
    defstruct @enforce_keys
  end

  # REALLY EACH STEP SHOULD HAVE AN ERROR NOT THE ROOT.
  # root can still have valid?. Actually cool to think about "it's valid if X% of steps have no errors"
  # or whatever.
  @enforce_keys [:state, :steps, :on_error]
  defstruct [:state, :steps, :on_error, errors: [], valid?: true]

  @doc """
  This is a default on_error which just returns the error message in an error tuple.
  """
  def on_error_identity(stuff), do: stuff

  @doc """
  Creates a new Domain.Request, with an optional on_error. If we make this a library function the
  default should be identity function, and we should encourage users to create their own `new`
  functions that provide on_errors if they want to use one.
  """
  def new(state, on_error) do
    %Domain.Request{state: state, steps: [], on_error: on_error}
  end

  @doc """
  Adds a step to the Request.
  """
  def add_step(request = %__MODULE__{}, action, options \\ []) do
    step = %Domain.Request.Step{
      action: action,
      on_error: Keyword.get(options, :on_error, request.on_error)
    }

    %{request | steps: request.steps ++ [step]}
  end

  @doc """
  Processes the request by executing each step, stopping immediately if any step returns an error
  tuple. If an error tuple is returned the error is given to on_error and the result is returned.

  This could be contrasted to a fail_last, which will collect all errors into the Request
  state and return that at the end.
  """
  def fail_fast(req = %Domain.Request{steps: steps}) do
    steps
    |> Enum.reduce_while(req, fn step = %Domain.Request.Step{}, acc ->
      with {:ok, result = %Domain.Request{}} <- step.action.(acc) do
        {:cont, result}
      else
        {:error, message} -> {:halt, %{acc | valid?: false, errors: [step.on_error.(message)]}}
      end
    end)
  end

  @doc """
  If the Request is valid we pass it into on_success, if it is invalid we pass it to
  on_error, the result it returned.
  """
  # We could label these or accept a map so that we don't mess up the on_success / on_error order
  def unwrap(req = %{valid?: true}, on_success, _on_error), do: on_success.(req)
  def unwrap(req = %{valid?: false}, _on_success, on_error), do: on_error.(req)

  # This is a bit more experimental so is yet untested. If we do this we need to have an errors on
  # the struct so we have somewhere to collect them.
  # def collect_errors(req = %Domain.Request{steps: steps, errors: errors, state: state}) do
  #   steps
  #   |> Enum.reduce_while({:ok, req}, fn step = %Domain.Request.Step{}, {:ok, acc} ->
  #     with result = {:ok, %Domain.Request{}} <- step.action.(acc) do
  #       {:cont, result}
  #     else
  #       {:error, message} ->
  # request = %{acc | errors: errors ++ [step.on_error.(message)]}
  #         {:cont, {:ok, request}}
  #     end
  #   end)
  # end

  # We implement the access behaviour so we can lens in and out easily. This is useful when
  # transforming nested data in the state.
  defdelegate get_and_update(map, key, fun), to: Map
  defdelegate fetch(map, key), to: Map
  defdelegate pop(map, key, default \\ nil), to: Map

  # Implementing this succinct, powerful steps that apply to a subset of the state in the Request
  defimpl KeywordLens do
    defdelegate map(request, keyword_lens, fun), to: KeywordLens.Map
    defdelegate map_while(request, keyword_lens, fun), to: KeywordLens.Map
    defdelegate reduce_while(request, keyword_lens, acc, fun), to: KeywordLens.Map
  end
end
