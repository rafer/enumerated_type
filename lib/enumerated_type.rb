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

  private

  def initialize(name, properties)
    @name = name
    properties.each { |k, v| send(:"#{k}=", v.freeze) }
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

    def [](name)
      each { |e| return e if e.name == name }
      raise ArgumentError, "Unrecognized #{self.name} name #{name.inspect}'"
    end

    def recognized?(name)
      map(&:name).include?(name)
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

        unless instance_methods.include?(:"#{property}")
          attr_reader(:"#{property}")
        end

        unless instance_methods.include?(:"#{property}=")
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
