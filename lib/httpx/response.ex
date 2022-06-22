defmodule HTTPX.Response do
  @moduledoc ~S"""
  HTTP response.
  """

  @typedoc ~S"""
  HTTP response.
  """
  @type t :: %__MODULE__{
          status: pos_integer,
          headers: [{String.t(), String.t()}],
          body: binary | map | list | number | boolean | nil
        }

  @enforce_keys [:status]
  defstruct [
    :status,
    headers: [],
    body: ""
  ]
end
