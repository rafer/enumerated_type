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
    lambda { Gender.new }.must_raise(NoMethodError)
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
      lambda { Gender.declare }.must_raise(NoMethodError)
    end

    it "requires the name to be unique" do
      duplicate_name = Gender.first.name
      lambda { Gender.send(:declare, duplicate_name) }.must_raise(ArgumentError)
    end

    it "produces frozen instances" do
      Gender.all?(&:frozen?).must_equal true
    end

    it "assigns properties and makes them accessible" do
      Gender.map(&:planet).must_equal ["mars", "venus"]
    end

    it "freezes String properties" do
      Gender::MALE.planet.frozen?.must_equal true
    end

    it "does not freeze other properties" do
      NonString = Class.new do
        def frozen?
          !!@frozen
        end

        def freeze
          @frozen = true
        end
      end

      non_string = NonString.new

      Class.new do
        include EnumeratedType
        declare :test, :other => non_string
      end

      non_string.frozen?.must_equal false
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

      name_property_definition.must_raise(ArgumentError)
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

  describe ".coerce" do
    it "returns the correct type if given a recognized symbol" do
      Gender.coerce(:female).must_equal Gender::FEMALE
    end

    it "returns the correct type if given a recognized string" do
      Gender.coerce("female").must_equal Gender::FEMALE
    end

    it "returns the correct type if given something that responds to #to_str" do
      stringlike = Object.new
      def stringlike.to_str
        "female"
      end

      Gender.coerce(stringlike).must_equal Gender::FEMALE
    end

    it "returns the object unmodified if given an instance of the enumerated type" do
      Gender.coerce(Gender::FEMALE).must_equal Gender::FEMALE
    end

    it "raises a TypeError if given something that isn't coercable" do
      lambda { Gender.coerce(Object.new) }.must_raise(TypeError)
    end

    it "raises a ArgumentError if given something coercable but not recognized" do
      lambda { Gender.coerce(:neuter) }.must_raise(ArgumentError)
    end
  end

  describe ".by" do
    class Shapes
      include EnumeratedType

      declare :triangle, :sides => 3, :pretty_hip => "YEAH"
      declare :rectangle, :sides => 4, :pretty_hip => "NAH"
      declare :pentagon, :sides => 5, :pretty_hip => "YEAH"

      def sides_squared
        sides * sides
      end
    end

    it "looks the value up by the specified attribute" do
      Shapes.by(:sides, 4).must_equal(Shapes::RECTANGLE)
    end

    it "raises an argumetn if there is no match" do
      lambda { Shapes.by(:sides, 6) }.must_raise(ArgumentError)
    end

    it "returns the first declared value if there is more than one match" do
      Shapes.by(:pretty_hip, "YEAH").must_equal(Shapes::TRIANGLE)
    end

    it "works with arbitrary methods" do
      Shapes.by(:sides_squared, 16).must_equal(Shapes::RECTANGLE)
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

  describe "#to_json" do
    it "is the name (as a string)" do
      Gender::MALE.to_json.must_equal '"male"'
    end

    it "doesn't raise an exception when given options" do
      Gender::MALE.to_json(:stuff => "here")
    end
  end

  describe "#as_json" do
    it "is the name (as a string)" do
      Gender::MALE.as_json.must_equal "male"
    end

    it "doesn't raise an exception when given options" do
      Gender::MALE.as_json(:stuff => "here")
    end
  end
end
