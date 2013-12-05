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

  def initialize(name, value, options = {})
    @name  = name
    @value = value

    options.each { |k, v| send(:"#{k}=", v) }
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

    def by_value(value)
      each { |e| return e if e.value == value }
      raise ArgumentError, "Unrecognized #{self.name} value #{value.inspect}'"
    end

    def by_name(name)
      each { |e| return e if e.name == name }
      raise ArgumentError, "Unrecognized #{self.name} name #{name.inspect}'"
    end

    def [](name)
      by_name(name)
    end

    def recognized?(name)
      map(&:name).include?(name)
    end

    private

    def declare(name, options = {})
      value = options.delete(:value)
      value ||= (map(&:value).max || 0) + 1

      if map(&:name).include?(name)
        raise(ArgumentError, "duplicate name #{name.inspect}")
      end

      if map(&:value).include?(value)
        raise(ArgumentError, "duplicate :value #{value.inspect}")
      end

      define_method(:"#{name}?") do
        self.name == name
      end

      enumerated = new(name, value, options)

      @all << enumerated
      const_set(name.to_s.upcase, enumerated)
    end
  end
end
