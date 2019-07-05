defmodule KniggeTest do
  use ExUnit.Case, async: true

  describe ".fetch!/2" do
    test "with a module not using Knigge" do
      assert_raise ArgumentError,
                   "expected a module using Knigge but DoesNotExist does not.",
                   fn ->
                     Knigge.fetch!(DoesNotExist, :implementation)
                   end
    end

    test "with a module using Knigge" do
      defmodule MyModuleUsingKnigge do
        use Knigge, implementation: Something

        @callback my_function() :: no_return
      end

      assert Knigge.fetch!(MyModuleUsingKnigge, :behaviour) == MyModuleUsingKnigge
      assert Knigge.fetch!(MyModuleUsingKnigge, :implementation) == Something
    end
  end
end
