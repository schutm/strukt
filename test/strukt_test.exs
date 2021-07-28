defmodule Strukt.Test do
  use ExUnit.Case, async: true

  doctest Strukt

  alias Uniq.UUID
  # See test/support/defstruct_fixtures.ex
  alias Strukt.Test.Fixtures

  test "when defstruct/1 is given a list of field names, it delegates to Kernel.defstruct/1" do
    assert %Fixtures.Classic{name: nil} = %Fixtures.Classic{}
    refute function_exported?(Fixtures.Classic, :new, 1)
    refute Map.has_key?(Map.from_struct(%Fixtures.Classic{}), :uuid)
  end

  test "default values are present when creating new struct" do
    assert {:ok, %Fixtures.Simple{name: ""}} = Fixtures.Simple.new()
  end

  test "default primary key is autogenerated by new/1" do
    assert {:ok, %Fixtures.Simple{uuid: uuid}} = Fixtures.Simple.new()
    assert {:ok, info} = UUID.info(uuid)
    assert 4 == info.version
  end

  test "can cast primary key from params" do
    uuid = UUID.uuid4()

    assert {:ok, %Fixtures.Simple{uuid: ^uuid}} = Fixtures.Simple.new(uuid: uuid)
  end

  test "can define a struct and its containing module inline using defstruct/2" do
    uuid = UUID.uuid4()

    assert {:ok, %Fixtures.Inline{uuid: ^uuid, name: ""}} = Fixtures.Inline.new(uuid: uuid)
    assert true = Fixtures.Inline.test()
  end

  test "can define embedded structs, using the same syntax as defstruct" do
    assert {:ok, %Fixtures.Embedded{uuid: uuid, items: []}} = Fixtures.Embedded.new()

    refute is_nil(uuid)

    assert {:ok, %Fixtures.Embedded.Item{uuid: item_uuid, name: "foo"}} =
             Fixtures.Embedded.Item.new(name: "foo")

    refute is_nil(item_uuid)
  end

  test "can cast embeds from params" do
    assert {:ok, %Fixtures.Embedded{items: [item]}} =
             Fixtures.Embedded.new(items: [%{name: "foo"}])

    assert %Fixtures.Embedded.Item{name: "foo"} = item

    assert {:ok, %Fixtures.Embedded{items: []} = embed} = Fixtures.Embedded.new()

    assert {:ok, %Fixtures.Embedded{items: [^item]}} =
             Fixtures.Embedded.change(embed, items: [Map.from_struct(item)])
             |> Fixtures.Embedded.from_changeset()
  end

  test "can specify an alternate primary key field" do
    assert {:ok, %Fixtures.AltPrimaryKey{id: nil, name: ""}} = Fixtures.AltPrimaryKey.new()

    refute Map.has_key?(Map.from_struct(%Fixtures.AltPrimaryKey{}), :uuid)
  end

  test "can specify an alternate primary key field via @primary_key attribute" do
    assert {:ok, %Fixtures.AttrPrimaryKey{id: id, name: ""}} = Fixtures.AttrPrimaryKey.new()
    refute is_nil(id)
    assert is_integer(id)

    refute Map.has_key?(Map.from_struct(%Fixtures.AttrPrimaryKey{}), :uuid)
  end

  test "generated primary keys are unique" do
    assert {:ok, %Fixtures.Simple{uuid: uuid1}} = Fixtures.Simple.new()
    assert {:ok, %Fixtures.Simple{uuid: uuid2}} = Fixtures.Simple.new()

    refute uuid1 == uuid2

    assert {:ok, %Fixtures.AttrPrimaryKey{id: id1}} = Fixtures.AttrPrimaryKey.new()
    assert {:ok, %Fixtures.AttrPrimaryKey{id: id2}} = Fixtures.AttrPrimaryKey.new()

    refute id1 == id2
  end

  test "using ecto schema reflection to form a struct" do
    params = %{NAME: "name", camelCaseKey: "key"}

    assert {
             :ok,
             %Strukt.Test.Fixtures.CustomFields{
               camel_case_key: "key",
               name: "name",
               uuid: _
             }
           } = Fixtures.CustomFields.new(params)
  end

  test "can parse custom fields for embedded schema" do
    params = %{
      NAME: "embedded",
      items: [%{itemName: "first item"}, %{itemName: "second item"}],
      meta: %{SOURCE: "iOS", Status: 1}
    }

    assert {:ok,
            %Strukt.Test.Fixtures.CustomFieldsWithEmbeddedSchema{
              items: [
                %Strukt.Test.Fixtures.CustomFieldsWithEmbeddedSchema.Item{
                  name: "first item",
                  uuid: nil
                },
                %Strukt.Test.Fixtures.CustomFieldsWithEmbeddedSchema.Item{
                  name: "second item",
                  uuid: nil
                }
              ],
              meta: %Strukt.Test.Fixtures.CustomFieldsWithEmbeddedSchema.Meta{
                source: "iOS",
                status: 1,
                uuid: nil
              },
              name: "embedded",
              uuid: uuid
            }} = Fixtures.CustomFieldsWithEmbeddedSchema.new(params)

    refute is_nil(uuid)

    params_with_nil_value = %{
      NAME: nil,
      items: nil,
      meta: nil
    }

    assert {:ok,
            %Strukt.Test.Fixtures.CustomFieldsWithEmbeddedSchema{
              items: [],
              meta: nil,
              name: nil,
              uuid: uuid2
            }} = Fixtures.CustomFieldsWithEmbeddedSchema.new(params_with_nil_value)

    refute is_nil(uuid2)
  end

  test "can parse the params that inside the embedded module with required virtual field" do
    params = %{
      profile: %{name: "Rafael", PHONE: "+886999888777"},
      wallets: [%{currency: "BTC", amount: 10, native_currency: "USD"}]
    }

    assert {:ok,
            %Strukt.Test.Fixtures.EmbeddedWithVirtualField{
              profile: %Strukt.Test.Fixtures.ProfileWithVirtualField{
                name: "Rafael",
                phone: "+886999888777",
                uuid: nil
              },
              uuid: _uuid,
              wallets: [
                %Strukt.Test.Fixtures.WalletWithVirtualField{
                  amount: 10,
                  currency: "BTC",
                  native_currency: "USD",
                  uuid: nil
                }
              ]
            }} = Fixtures.EmbeddedWithVirtualField.new(params)

    struct_params = %{
      profile: %Strukt.Test.Fixtures.ProfileWithVirtualField{
        name: "Rafael",
        phone: "+886999888777"
      },
      wallets: [
        %Strukt.Test.Fixtures.WalletWithVirtualField{
          currency: "BTC",
          amount: 10,
          native_currency: "USD"
        }
      ]
    }

    assert {:ok,
            %Strukt.Test.Fixtures.EmbeddedWithVirtualField{
              profile: %Strukt.Test.Fixtures.ProfileWithVirtualField{
                name: "Rafael",
                phone: nil,
                uuid: nil
              },
              uuid: _uuid,
              wallets: [
                %Strukt.Test.Fixtures.WalletWithVirtualField{
                  amount: 10,
                  currency: "BTC",
                  native_currency: "USD",
                  uuid: nil
                }
              ]
            }} = Fixtures.EmbeddedWithVirtualField.new(struct_params)
  end

  test "can parse the params that inside the embedded inline module with required virtual field" do
    params = %{
      profile: %{name: "Rafael"},
      wallets: [%{currency: "BTC"}]
    }

    assert {:ok,
            %Strukt.Test.Fixtures.EmbeddedInlineModuleWithVirtualField{
              profile: %Strukt.Test.Fixtures.EmbeddedInlineModuleWithVirtualField.Profile{
                name: "Rafael",
                uuid: nil
              },
              uuid: _uuid,
              wallets: [
                %Strukt.Test.Fixtures.EmbeddedInlineModuleWithVirtualField.Wallet{
                  currency: "BTC",
                  uuid: nil
                }
              ]
            }} = Fixtures.EmbeddedInlineModuleWithVirtualField.new(params)
  end

  test "can parse the params that contain nil value in embedded field" do
    params = %{profile: nil, walles: nil}

    assert {:ok,
            %Strukt.Test.Fixtures.EmbeddedParentSchema{profile: nil, uuid: uuid, wallets: []}} =
             Fixtures.EmbeddedParentSchema.new(params)

    refute is_nil(uuid)
  end

  test "can parse the params to the virtual field" do
    params = %{name: "Daniel", phone: "+85299887766"}

    assert {:ok,
            %Strukt.Test.Fixtures.VirtualField{
              name: "Daniel",
              phone: "+85299887766",
              uuid: uuid
            }} = Fixtures.VirtualField.new(params)

    refute is_nil(uuid)
  end

  test "can parse the params to the InlineSchema virtual field" do
    params = %{name: "Daniel", phone: "+85299887766"}

    assert {
             :ok,
             %Strukt.Test.Fixtures.InlineVirtualField{
               name: "Daniel",
               phone: "+85299887766",
               uuid: uuid
             }
           } = Fixtures.InlineVirtualField.new(params)

    refute is_nil(uuid)
  end

  test "parse custom fields with empty params" do
    assert {:ok,
            %Strukt.Test.Fixtures.CustomFieldsWithEmbeddedSchema{
              items: [],
              meta: nil,
              name: nil,
              uuid: uuid
            }} = Fixtures.CustomFieldsWithEmbeddedSchema.new()

    refute is_nil(uuid)
  end

  test "parse custom fields with boolean value" do
    assert {:ok, %Strukt.Test.Fixtures.CustomFieldsWithBoolean{enabled: false, uuid: uuid}} =
             Fixtures.CustomFieldsWithBoolean.new(%{Enabled: false})

    refute is_nil(uuid)
  end

  test "can derive a json encoder" do
    assert {:ok, %Fixtures.JSON{} = obj} = Fixtures.JSON.new()

    assert {:ok, json} = Jason.encode(obj)

    assert {:ok, ^obj} = Fixtures.JSON.from_json(json)
  end

  test "can control struct generation with outer attributes" do
    assert {:ok, %Fixtures.OuterAttrs{} = obj} = Fixtures.OuterAttrs.new()

    assert {:ok, _} = UUID.info(obj.uuid)
    assert %DateTime{} = obj.inserted_at

    assert {:ok, json} = Jason.encode(obj)

    assert {:ok, ^obj} = Fixtures.OuterAttrs.from_json(json)
  end

  test "usings/imports are scoped correctly when using defstruct/2" do
    assert {:ok, %Fixtures.OuterScope.InnerScope{} = scope} = Fixtures.OuterScope.InnerScope.new()
    refute scope.uuid == nil
    assert %DateTime{} = scope.inserted_at
  end

  test "can express validations inline with field definitions" do
    assert {:error, changeset} = Fixtures.Validations.new()

    assert %{name: ["can't be blank"], email: ["must provide an email"]} ==
             changeset_errors(changeset)
  end

  test "can modify a struct and validate the changes" do
    assert {:ok, valid} =
             Fixtures.Validations.new(
               name: "Bobby Tables",
               email: "bobby.tables@example.com",
               age: 120,
               status: :green
             )

    assert %Ecto.Changeset{} = changeset = Fixtures.Validations.change(valid, age: 0)

    assert {:error, %Ecto.Changeset{}} = Fixtures.Validations.from_changeset(changeset)

    assert %{age: ["must be greater than 0"]} = changeset_errors(changeset)
  end

  test "can require that an embed be present" do
    assert {:error, changeset} = Fixtures.ValidateRequiredEmbed.new()
    assert %{embedded: ["embed must be set"]} = changeset_errors(changeset)
  end

  test "can correctly validate enums" do
    params = [
      name: "Bobby Tables",
      email: "bobby.tables@example.com",
      age: 120
    ]

    assert {:error, %Ecto.Changeset{} = changeset} =
             Fixtures.Validations.new(Keyword.merge(params, status: 123))

    assert %{status: ["is invalid"]} = changeset_errors(changeset)
  end

  test "can correctly validate string lengths" do
    params = [exact: "abc", bounded_graphemes: "ááá", bounded_bytes: "abc"]
    assert {:ok, _} = Fixtures.ValidateLengths.new(params)

    assert {:error, changeset} = Fixtures.ValidateLengths.new(Keyword.merge(params, exact: ""))

    assert %{exact: ["must be 3 characters"]} = changeset_errors(changeset)

    assert {:error, changeset} =
             Fixtures.ValidateLengths.new(Keyword.merge(params, exact: "abcd"))

    assert %{exact: ["must be 3 characters"]} = changeset_errors(changeset)

    assert {:error, changeset} =
             Fixtures.ValidateLengths.new(Keyword.merge(params, bounded_bytes: ""))

    assert %{bounded_bytes: ["must be between 1 and 3 bytes"]} = changeset_errors(changeset)

    assert {:error, changeset} =
             Fixtures.ValidateLengths.new(Keyword.merge(params, bounded_bytes: "ábc"))

    assert %{bounded_bytes: ["must be between 1 and 3 bytes"]} = changeset_errors(changeset)

    assert {:error, changeset} =
             Fixtures.ValidateLengths.new(Keyword.merge(params, bounded_graphemes: ""))

    assert %{bounded_graphemes: ["must be between 1 and 3 graphemes"]} =
             changeset_errors(changeset)

    assert {:error, changeset} =
             Fixtures.ValidateLengths.new(Keyword.merge(params, bounded_graphemes: "áááá"))

    assert %{bounded_graphemes: ["must be between 1 and 3 graphemes"]} =
             changeset_errors(changeset)
  end

  test "can correctly validate set membership" do
    params = [one_of: "a", none_of: "d", subset_of: ["a", "c"]]
    assert {:ok, _} = Fixtures.ValidateSets.new(params)

    assert {:error, changeset} = Fixtures.ValidateSets.new(Keyword.merge(params, one_of: "d"))
    assert %{one_of: ["must be one of [a, b, c]"]} = changeset_errors(changeset)

    assert {:error, changeset} = Fixtures.ValidateSets.new(Keyword.merge(params, none_of: "a"))
    assert %{none_of: ["cannot be one of [a, b, c]"]} = changeset_errors(changeset)

    assert {:error, changeset} =
             Fixtures.ValidateSets.new(Keyword.merge(params, subset_of: ["a", "b", "d"]))

    assert %{subset_of: ["has an invalid entry"]} = changeset_errors(changeset)
  end

  test "can correctly validate numbers" do
    params = [bounds: 2, bounds_inclusive: 1, eq: 1, neq: 0, range: 1]
    assert {:ok, _} = Fixtures.ValidateNumbers.new(params)

    assert {:error, changeset} = Fixtures.ValidateNumbers.new(Keyword.merge(params, bounds: 1))
    assert %{bounds: ["must be greater than 1"]} = changeset_errors(changeset)

    assert {:error, changeset} = Fixtures.ValidateNumbers.new(Keyword.merge(params, bounds: 100))
    assert %{bounds: ["must be less than 100"]} = changeset_errors(changeset)

    assert {:ok, _} = Fixtures.ValidateNumbers.new(Keyword.merge(params, bounds_inclusive: 100))

    assert {:error, changeset} =
             Fixtures.ValidateNumbers.new(Keyword.merge(params, bounds_inclusive: 0))

    assert %{bounds_inclusive: ["must be greater than or equal to 1"]} =
             changeset_errors(changeset)

    assert {:error, changeset} =
             Fixtures.ValidateNumbers.new(Keyword.merge(params, bounds_inclusive: 101))

    assert %{bounds_inclusive: ["must be less than or equal to 100"]} =
             changeset_errors(changeset)

    assert {:error, changeset} = Fixtures.ValidateNumbers.new(Keyword.merge(params, eq: 2))
    assert %{eq: ["must be equal to 1"]} = changeset_errors(changeset)

    assert {:error, changeset} = Fixtures.ValidateNumbers.new(Keyword.merge(params, neq: 1))
    assert %{neq: ["must be not equal to 1"]} = changeset_errors(changeset)

    assert {:error, changeset} = Fixtures.ValidateNumbers.new(Keyword.merge(params, range: 0))
    assert %{range: ["must be in the range 1..100"]} = changeset_errors(changeset)
  end

  defp changeset_errors(%Ecto.Changeset{} = cs) do
    cs
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn
        {key, {:parameterized, Ecto.Enum, %{values: values}}}, acc ->
          String.replace(acc, "%{#{key}}", values |> Enum.map(&to_string/1) |> Enum.join(", "))

        {key, %Range{} = value}, acc ->
          String.replace(acc, "%{#{key}}", inspect(value))

        {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
