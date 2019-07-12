defmodule Knigge do
  @moduledoc """
  `Knigge` offers an opinionated way of dealing with elixir behaviours.

  Opinionated means that it offers an easy way of defining a "facade" for a
  behaviour which then delegates calls to the real implementation, which is
  either given directly to `Knigge` or fetched from the configuration.

  `Knigge` can either be used directly in a behaviour or in separate module by
  passing the behaviour which should be "facaded" as an option to `Knigge`.

  ## Examples

  Imagine a behaviour looking like this:

      defmodule MyGreatBehaviour do
        @callback my_great_callback(my_argument :: any()) :: any()
      end

  Now imagine you want to delegate calls to this behaviour like this:

      defmodule MyGreatBehaviourFacade do
        @behaviour MyGreatBehaviour

        @implementation Application.get_env(:my_application, MyGreatBehaviour)

        defdelegate my_great_callback, to: @implementation
      end

  With this in place you can simply reference the "real implementation" by
  calling functions on your facade:

      MyGreatBehaviourFacade.my_great_callback(:with_some_argument)

  `Knigge` allows you to reduce this boilerplate to the absolute minimum:

      defmodule MyGreatBehaviourFacade do
        use Knigge,
          behaviour: MyGreatBehaviour,
          otp_app: :my_application
      end

  Under the hood this compiles down to the explicit delegation visible on the top.
  In case you don't want to fetch your implementation from the configuration,
  `Knigge` also allows you to explicitely pass the implementation of the
  behaviour with the aptly named key `implementation`:

      defmodule MyGreatBehaviourFacade do
        use Knigge,
          behaviour: MyGreatBehaviour,
          implementation: MyGreatImplementation
      end

  `Knigge` expects either the `otp_app` key or the `implementation` key. If
  neither is provided an error will be raised at compile time.
  """

  @type key :: :behaviour | :implementation | :options

  defmacro __using__(options) do
    Knigge.Options.validate!(options)

    quote do
      @before_compile Knigge.Delegation

      @__knigge__ [
        behaviour: Knigge.Behaviour.fetch!(__MODULE__, unquote(options)),
        implementation: Knigge.Implementation.fetch!(__MODULE__, unquote(options)),
        options: unquote(options)
      ]

      @doc "Access Knigge internal values, such as the implementation being delegated to etc."
      @spec __knigge__(:behaviour) :: module()
      @spec __knigge__(:implementation) :: module()
      @spec __knigge__(:options) :: Knigge.Options.t()
      def __knigge__(key), do: Keyword.fetch!(@__knigge__, key)
    end
  end

  @doc "Access Knigge internal values, such as the implementation being delegated to etc."
  @spec fetch!(module(), :behaviour) :: module()
  @spec fetch!(module(), :implementation) :: module()
  @spec fetch!(module(), :options) :: Knigge.Options.t()
  def fetch!(module, key) do
    cond do
      Module.open?(module) ->
        module
        |> Module.get_attribute(:__knigge__)
        |> Keyword.fetch!(key)

      function_exported?(module, :__knigge__, 1) ->
        module.__knigge__(key)

      true ->
        raise ArgumentError, "expected a module using Knigge but #{inspect(module)} does not."
    end
  end
end
