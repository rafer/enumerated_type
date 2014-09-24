require "enumerated_type/version"

module EnumeratedType
  # In the unfortunate case where there are thousands of elements in an
  # enumerated type, an iteration based strategy for EnumeratedType.by is slow.
  # Particularly, since declare does .by(:name, name) to detect name
  # collisions, EnumeratedType.declare is O(n^2) where n is the
  # EnumeratedType.count, which can take seconds when the enunm is loaded,
  # which is, like, a total bummer.  This class indexes enums by property and
  # value so lookups are constant time. The backing hash would look like this
  # for the Shape enum.
  #
  # {
  #   :sides => {
  #     4 => Shape::Square
  #   },
  #   :name => {
  #     :square => Shape::Square
  #   }
  # }
  #
  # Note that there is only a single value for each property/value combination.
  # #set will respect the first instance of a property/value combination (i.e
  # subsequent duplicate #sets will not override the first value). This matches
  # the definition of EnumeratedType.by.
  class PropertyIndex
    def initialize
      self.by_property = { }
    end

    def set(property, value, enumerated)
      by_value = (by_property[property.to_sym] ||= { })
      by_value[value] ||= enumerated
    end

    def get(property, value, miss)
      by_property.fetch(property.to_sym).fetch(value, &miss)
    end

    def has_property?(property)
      by_property.has_key?(property.to_sym)
    end

    private

    attr_accessor :by_property
  end

  def self.included(base)
    base.instance_eval do
      @all = []
      @by_cache = PropertyIndex.new

      attr_reader :name, :value

      private_class_method :new

      extend Enumerable
      extend ClassMethods
    end
  end

  def inspect
    "#<#{self.class.name}:#{name}>"
  end

  def to_s
    name.to_s
  end

  def to_json(*)
    '"' + as_json + '"'
  end

  def as_json(*)
    name.to_s
  end

  private

  def initialize(name, properties)
    @name = name
    properties.each { |k, v| send(:"#{k}=", v) }
    properties.values.each { |v| v.freeze if v.is_a?(String) }
  end

  def self.new(*names)
    names = names.first if names.first.kind_of?(Enumerable)

    Class.new do
      include EnumeratedType
      names.each { |n| declare(n) }
    end
  end

  module ClassMethods
    def each(&block)
      @all.each(&block)
    end

    def by(property, value, &miss)
      miss ||= Proc.new { |v| raise(ArgumentError, "Could not find #{self.name} with ##{property} == #{v.inspect}'") }

      if @by_cache.has_property?(property)
        @by_cache.get(property, value, miss)
      else
        find { |e| e.send(property) == value } || miss.call(value)
      end
    end

    def [](name)
      by(:name, name)
    end

    def recognized?(name)
      map(&:name).include?(name)
    end

    def coerce(coercable)
      case
      when coercable.class == self then coercable
      when coercable.respond_to?(:to_sym) then self[coercable.to_sym]
      when coercable.respond_to?(:to_str) then self[coercable.to_str.to_sym]
      else
        raise TypeError, "#{coercable.inspect} cannot be coerced into a #{self.name}"
      end
    end

    private

    def declare(name, options = {})
      unless by(:name, name) { :not_found } == :not_found
        raise(ArgumentError, "duplicate name #{name.inspect}")
      end

      define_method(:"#{name}?") do
        self.name == name
      end

      options.keys.each do |property|
        if property.to_s == "name"
          raise ArgumentError, "Property name 'name' is not allowed (conflicts with default EnumeratedType#name)"
        end

        attr_accessor(:"#{property}")
        private(:"#{property}=")
      end

      enumerated = new(name, options).freeze

      (options.keys + [:name]).each do |property|
        @by_cache.set(property, enumerated.send(property), enumerated)
      end

      @all << enumerated
      const_set(name.to_s.upcase, enumerated)
    end
  end
end
