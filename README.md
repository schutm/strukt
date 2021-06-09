# Strukt

Strukt provides an extended `defstruct` macro which builds on top of `Ecto.Schema`
and `Ecto.Changeset` to remove the boilerplate of defining type specifications,
implementing validations, generating changesets from parameters, JSON serialization,
and support for autogenerated fields.

This builds on top of Ecto embedded schemas, so the same familiar syntax you use today
to define schema'd types in Ecto, can now be used to define structs for general purpose
usage.

The functionality provided by the `defstruct` macro in this module is strictly a superset
of the functionality provided both by `Kernel.defstruct/1`, as well as `Ecto.Schema`. If
you import it in a scope where you use `Kernel.defstruct/1` already, it will not interfere.
Likewise, the support for defining validation rules inline with usage of `field/3`, `embeds_one/3`,
etc., is strictly additive, and those additions are stripped from the AST before `field/3`
and friends ever see it.

## Installation

``` elixir
def deps do
  [
    {:strukt, "~> 0.1"}
  ]
end
```

## Example

The following is an example of using `defstruct/1` to define a struct with types, autogenerated
primary key, and validation rules.


``` elixir
defmodule Person do
  use Strukt
  
  @derives [Jason.Encoder]
  @primary_key {:uuid, Ecto.UUID, autogenerate: true}
  @timestamps_opts [autogenerate: {NaiveDateTime, :utc_now, []}]

  defstruct do
    field :name, :string, required: true
    field :email, :string, format: ~r/^.+@.+$/
    
    timestamps()
  end
end
```

And an example of how you would create and use this struct:

``` elixir
# Creating from params, with autogeneration of fields
iex> {:ok, person} = Person.new(name: "Paul", email: "bitwalker@example.com")
...> person
%Person{
  uuid: "d420aa8a-9294-4977-8b00-bacf3789c702", 
  name: "Paul", 
  email: "bitwalker@example.com", 
  inserted_at: ~N[2021-06-08 22:21:23.490554], 
  updated_at: ~N[2021-06-08 22:21:23.490554]
}

# Validation (Create)
iex> {:error, %Ecto.Changeset{valid?: false, errors: errors}} = Person.new(email: "bitwalker@example.com")
...> errors
[name: {"can't be blank", [validation: :required]}]

# Validation (Update)
iex> {:ok, person} = Person.new(name: "Paul", email: "bitwalker@example.com")
...> {:error, %Ecto.Changeset{valid?: false, errors: errors}} = Person.change(person, email: "foo")
...> errors
[email: {"has invalid format", [validation: :format]}]

# JSON Serialization/Deserialization
...> person == person |> Jason.encode!() |> Person.from_json()
true
```

For more, see the [usage docs](https://hexdocs.pm/strukt/usage.html)
