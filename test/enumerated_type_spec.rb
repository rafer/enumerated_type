require "bundler/setup"

require "minitest"
require "minitest/pride"

require "enumerated_type"

describe EnumeratedType do
  class Gender
    include EnumeratedType

    attr_accessor :planet

    declare(:male, :planet => "mars")
    declare(:female, :planet => "venus")
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

    it "allows you to specify :value" do
      gender = Class.new do
        include EnumeratedType
        declare :male, :value => 100
        declare :female, :value => 101
      end

      gender.map(&:value).must_equal [100, 101]
    end

    it "requires :value to be unique" do
      duplicate_value = Gender.first.value

      lambda { Gender.send(:declare, :neuter, :value => duplicate_value ) }.must_raise(ArgumentError, /duplicate :value/)
    end

    it "assigns extra attributes from .declare" do
      Gender.map(&:planet).must_equal ["mars", "venus"]
    end
  end

  describe ".by_name" do
    it "returns the type with the given name" do
      gender = Gender.first
      Gender.by_name(gender.name).must_equal gender
    end

    it "raises an error given an unrecognized name" do
      lambda { Gender.by_name(:neuter) }.must_raise(ArgumentError)
    end
  end

  describe ".by_value" do
    it "returns the type with the given value" do
      gender = Gender.first
      Gender.by_value(gender.value).must_equal gender
    end

    it "raises an error given an unrecognized value" do
      lambda { Gender.by_value((Gender.map(&:value).max) + 1) }.must_raise(ArgumentError)
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
