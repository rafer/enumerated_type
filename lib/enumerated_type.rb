require "enumerated_type/version"

module EnumeratedType
  def self.included(base)
    base.instance_eval do
      @all = []

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
      miss ||= lambda { raise(ArgumentError, "Could not find #{self.name} with ##{property} == #{value.inspect}'") }
      find { |e| e.send(property) == value } || miss.call
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
      if map(&:name).include?(name)
        raise(ArgumentError, "duplicate name #{name.inspect}")
      end

      define_method(:"#{name}?") do
        self.name == name
      end

      options.keys.each do |property|
        if property.to_s == "name"
          raise ArgumentError, "Property name 'name' is not allowed (conflicts with default EnumeratedType#name)"
        end

        unless method_defined?(:"#{property}")
          attr_reader(:"#{property}")
        end

        unless method_defined?(:"#{property}=")
          attr_writer(:"#{property}")
          private(:"#{property}=")
        end
      end

      enumerated = new(name, options).freeze

      @all << enumerated
      const_set(name.to_s.upcase, enumerated)
    end
  end
end
