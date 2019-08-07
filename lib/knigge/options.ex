defmodule Knigge.Options do
  @moduledoc """
  Specifies valid `Knigge`-options and allows to validate and encapsulate the
  options in a struct.

  `Knigge` differentiates between **required** and _optional_ options:

  ## Required

  `Knigge` requires a way to determine the implementation to delegate to. As
  such it requires one of the following options (but not both):

  - `implementation` directly passes the implementation to delegate to
  - `otp_app` specifies the application for which the implementation has been configured

  If both or neither are given an `ArgumentError` is being raised.

  ## Optional

  These options do not have to be given but control aspects on how `Knigge` does
  delegation:

  - `behaviour` the behaviour for which `Knigge` should generate delegations,
    defaults to the `use`ing `__MODULE__`
  - `check_if_exists` controls how `Knigge` checks if the given modules exist by env,
    accepts a boolean, `[only: ...]` or `[except: ...]` with a single atom, or list of atoms,
    assumes `only` if an atom or a list of atoms is passed directly,
    defaults to `[except: :test]`
  - `config_key` the configuration key from which `Knigge` should fetch the implementation,
    defaults to the `use`ing `__MODULE__` and is only used when `otp_app` is passed
  - `delegate_at` an atom defining when delegation should happen, either `:compile_time` or `:runtime`,
    defaults to `:compile_time`
  - `do_not_delegate` a keyword list defining callbacks for which no delegation should happen
  - `warn` if set to `false` this disables all warnings generated by `Knigge`, use with care
  """

  import Keyword, only: [has_key?: 2, keyword?: 1]

  @type raw :: [required() | list(optional())]

  @type required :: {:implementation, implementation()} | {:otp_app, otp_app()}
  @type optional :: [
          behaviour: behaviour(),
          check_if_exists: check_if_exists(),
          config_key: config_key(),
          delegate_at: delegate_at(),
          do_not_delegate: do_not_delegate(),
          warn: warn()
        ]

  @type behaviour :: module()
  @type check_if_exists :: boolean() | envs() | [only: envs()] | [except: envs()]
  @type config_key :: atom()
  @type delegate_at :: :compile_time | :runtime
  @type do_not_delegate :: keyword(arity())
  @type implementation :: module()
  @type otp_app :: atom()
  @type warn :: boolean()

  @type envs :: atom() | list(atom())

  @type t :: %__MODULE__{
          implementation: implementation() | {:config, otp_app(), config_key()},
          behaviour: behaviour(),
          check_if_exists: check_if_exists(),
          delegate_at: delegate_at(),
          do_not_delegate: do_not_delegate(),
          warn: warn()
        }

  defstruct [
    :behaviour,
    :delegate_at,
    :check_if_exists,
    :do_not_delegate,
    :implementation,
    :warn
  ]

  @doc """
  Checks the validity of the given opts (`validate!/1`), applies defaults and
  puts them into the `#{inspect(__MODULE__)}`-struct.
  """
  @spec new(options :: raw()) :: t()
  def new(opts) do
    opts =
      opts
      |> validate!()
      |> with_defaults()
      |> Keyword.put_new_lazy(:implementation, fn ->
        {:config, opts[:otp_app], opts[:config_key]}
      end)
      |> Keyword.update!(:check_if_exists, fn
        [{key, envs}] -> [{key, List.wrap(envs)}]
        envs -> [only: List.wrap(envs)]
      end)

    struct(__MODULE__, opts)
  end

  @defaults [
    check_if_exists: [except: :test],
    delegate_at: :compile_time,
    do_not_delegate: [],
    warn: true
  ]

  @doc """
  Applies the defaults to the given options:
  #{
    @defaults
    |> Enum.map(fn {key, value} ->
      "  - #{key} = #{inspect(value)}"
    end)
    |> Enum.join("\n")
  }
  """
  @spec with_defaults(raw()) :: raw()
  def with_defaults(opts) do
    Keyword.merge(@defaults, opts)
  end

  @doc """
  Validates the options passed to `Knigge`. It ensures that the required keys
  are present and that no unknown keys are passed to `Knigge` which might
  indicate a spelling error.

  See the moduledocs for details on required and optional options.

  ## Examples

      iex> Knigge.Options.validate!([1, 2, 3])
      ** (ArgumentError) Knigge expects a keyword list as options, instead received: [1, 2, 3]

      iex> Knigge.Options.validate!([])
      ** (ArgumentError) Knigge expects either the :implementation or the :otp_app option but neither was given.

      iex> Knigge.Options.validate!(implementation: SomeModule)
      [implementation: SomeModule]

      iex> Knigge.Options.validate!(otp_app: :knigge)
      [otp_app: :knigge]

      iex> Knigge.Options.validate!(otp_app: :knigge, check_if_exists: [:test, :prod])
      [otp_app: :knigge, check_if_exists: [:test, :prod]]

      iex> Knigge.Options.validate!(implementation: SomeModule, otp_app: :knigge)
      ** (ArgumentError) Knigge expects either the :implementation or the :otp_app option but both were given.

      iex> Knigge.Options.validate!(otp_app: :knigge, the_answer_to_everything: 42, another_weird_option: 1337)
      ** (ArgumentError) Knigge received unexpected options: [the_answer_to_everything: 42, another_weird_option: 1337]

      iex> Knigge.Options.validate!(otp_app: "knigge")
      ** (ArgumentError) Knigge received invalid value for `otp_app`. Expected atom but received: "knigge"

      iex> Knigge.Options.validate!(otp_app: :knigge, delegate_at: :compailtime)
      ** (ArgumentError) Knigge received invalid value for `delegate_at`. Expected :compile_time or :runtime but received: :compailtime

      iex> Knigge.Options.validate!(otp_app: :knigge, check_if_exists: "test")
      ** (ArgumentError) Knigge received invalid value for `check_if_exists`. Expected boolean or environment (atom or list of atoms) but received: "test"
  """
  @spec validate!(raw()) :: no_return
  def validate!(opts) do
    validate_keyword!(opts)
    validate_required!(opts)
    validate_known!(opts)
    validate_values!(opts)

    opts
  end

  defp validate_keyword!(opts) do
    unless keyword?(opts) do
      raise ArgumentError,
            "Knigge expects a keyword list as options, instead received: #{inspect(opts)}"
    end

    :ok
  end

  defp validate_required!(opts) do
    case {has_key?(opts, :implementation), has_key?(opts, :otp_app)} do
      {false, false} ->
        raise ArgumentError,
              "Knigge expects either the :implementation or the :otp_app option but neither was given."

      {true, true} ->
        raise ArgumentError,
              "Knigge expects either the :implementation or the :otp_app option but both were given."

      _ ->
        :ok
    end
  end

  defp validate_known!(opts) do
    opts
    |> Enum.reject(&known?/1)
    |> case do
      [] ->
        :ok

      unknown ->
        raise ArgumentError, "Knigge received unexpected options: #{inspect(unknown)}"
    end
  end

  defp validate_values!(opts) do
    opts
    |> Enum.reject(&valid_value?/1)
    |> case do
      [] ->
        :ok

      [{name, value} | _] ->
        raise ArgumentError,
              "Knigge received invalid value for `#{name}`. " <>
                "Expected #{expected_value(name)} but received: #{inspect(value)}"
    end
  end

  @option_types [
    behaviour: :module,
    check_if_exists: :envs,
    delegate_at: [:compile_time, :runtime],
    do_not_delegate: :keyword,
    implementation: :module,
    otp_app: :atom,
    config_key: :atom,
    warn: :boolean
  ]

  @option_names Keyword.keys(@option_types)

  defp known?({name, _}), do: name in @option_names

  defp valid_value?({name, value}) do
    @option_types
    |> Keyword.fetch!(name)
    |> valid_value?(value)
  end

  defp valid_value?(:atom, value), do: is_atom(value)
  defp valid_value?(:boolean, value), do: is_boolean(value)
  defp valid_value?(:module, value), do: is_atom(value)
  defp valid_value?(:keyword, value), do: Keyword.keyword?(value)

  defp valid_value?(:envs, only: envs), do: valid_envs?(envs)
  defp valid_value?(:envs, except: envs), do: valid_envs?(envs)
  defp valid_value?(:envs, envs), do: valid_envs?(envs)

  defp valid_value?(values, value) when is_list(values), do: value in values

  defp valid_envs?(envs) do
    is_boolean(envs) or is_atom(envs) or (is_list(envs) and Enum.all?(envs, &is_atom/1))
  end

  defp expected_value(name) do
    case Keyword.fetch!(@option_types, name) do
      :envs ->
        "boolean or environment (atom or list of atoms)"

      :keyword ->
        "keyword list"

      list when is_list(list) ->
        list
        |> Enum.map(&inspect/1)
        |> Enum.join(" or ")

      other ->
        to_string(other)
    end
  end

  @env Mix.env()

  def check_if_exists?(%__MODULE__{check_if_exists: envs}), do: do_check_if_exists?(envs)

  defp do_check_if_exists?(boolean) when is_boolean(boolean), do: boolean
  defp do_check_if_exists?(only: envs), do: @env in envs
  defp do_check_if_exists?(except: envs), do: @env not in envs
end
