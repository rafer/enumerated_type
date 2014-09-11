require "enumerated_type/version"

module EnumeratedType
  class ByCache
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
      @by_cache = ByCache.new

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
      miss ||= Proc.new { raise(ArgumentError, "Could not find #{self.name} with ##{property} == #{value.inspect}'") }

      if @by_cache.has_property?(property)
        @by_cache.get(property, value, miss)
      else
        find { |e| e.send(property) == value } || miss.call
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
