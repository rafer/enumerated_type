require "bundler/setup"

require "minitest/autorun"
require "minitest/pride"

require "enumerated_type"

describe EnumeratedType do
  class Gender
    include EnumeratedType

    declare :male, :planet => "mars"
    declare :female, :planet => "venus"
  end

  it "privatizes the constructor" do
    lambda { Gender.new }.must_raise(NoMethodError, /private method `new' called/)
  end

  it "is enumerable" do
    Gender.must_be_kind_of Enumerable
  end

  it "enumerates over all the declared types" do
    Gender.entries.must_equal [Gender[:male], Gender[:female]]
  end

  it "declares an actual constant for each type" do
    Gender::MALE.must_be_same_as Gender[:male]
    Gender::FEMALE.must_be_same_as Gender[:female]
  end

  it "defines a predicate method for each type based on the name" do
    Gender.entries.map(&:male?).must_equal [true, false]
    Gender.entries.map(&:female?).must_equal [false, true]
  end

  describe ".new" do
    it "returns an anonymous class" do
      EnumeratedType.new.instance_of?(Class).must_equal true
      EnumeratedType.new.name.must_equal nil
    end

    it "returns a class that includes EnumeratedType" do
      gender = EnumeratedType.new
      gender.ancestors.include?(EnumeratedType).must_equal true
    end

    it "declares the given names as types (provided as arguments)" do
      gender = EnumeratedType.new(:male, :female)
      gender.map(&:name).must_equal [:male, :female]
    end

    it "declares the given names as types (provides as array)" do
      gender = EnumeratedType.new([:male, :female])
      gender.map(&:name).must_equal [:male, :female]
    end

    it "declares the given names as types (provides any enumerable)" do
      gender = EnumeratedType.new(Set.new([:male, :female]))
      gender.map(&:name).must_equal [:male, :female]
    end
  end

  describe ".declare" do
    it "is private" do
      lambda { Gender.declare }.must_raise(NoMethodError, /private method `declare' called/)
    end

    it "requires the name to be unique" do
      duplicate_name = Gender.first.name
      lambda { Gender.send(:declare, duplicate_name) }.must_raise(ArgumentError, /duplicate name/)
    end

    it "produces frozen instances" do
      Gender.all?(&:frozen?).must_equal true
    end

    it "assigns properties and makes them accessible" do
      Gender.map(&:planet).must_equal ["mars", "venus"]
    end

    it "freezes properties" do
      lambda { Gender::MALE.planet.replace("pluto") }.must_raise(RuntimeError, /can't modify frozen/)
    end

    it "does not expose public setters for properties" do
      Gender::MALE.respond_to?(:planet=).must_equal false
    end

    it "does not allow the property name 'name'" do
      name_property_definition = lambda do
        Class.new do
          include EnumeratedType
          declare :test, :name => "test"
        end
      end

      name_property_definition.must_raise(ArgumentError, "Property name 'name' is not allowed")
    end
  end

  describe ".[]" do
    it "returns the type with the given name" do
      gender = Gender.first
      Gender[gender.name].must_equal gender
    end

    it "raises an error given an unrecognized name" do
      lambda { Gender[:neuter] }.must_raise ArgumentError
    end
  end

  describe ".recognized?" do
    it "returns true if the name is declared" do
      Gender.recognized?(:male).must_equal true
    end

    it "returns false if the name is has not been declared" do
      Gender.recognized?(:neuter).must_equal false
    end
  end

  describe "#inspect" do
    it "looks reasonable" do
      Gender::FEMALE.inspect.must_equal "#<Gender:female>"
    end
  end

  describe "#to_s" do
    it "is the name (as a string)" do
      Gender::MALE.to_s.must_equal "male"
    end
  end
end
