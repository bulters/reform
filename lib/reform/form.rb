require 'delegate'

class Form  < SimpleDelegator
  # reasons for delegation:
  # presentation: this object is used in the presentation layer by #form_for.
  # problem: #form_for uses respond_to?(:email_before_type_cast) which goes to an internal hash in the actual record.
  # validation: this object also contains the validation rules itself, should be separated.

  # TODO: figure out #to_key issues.

  def initialize(mapper, comp) # model: new or existing?
    @mapper = mapper  # DISCUSS: not needed?
    @comp = comp
    # here the mapping between model(s) and form should happen.

    # this used to be our composition object with "magic" accessors:
    all_attributes_hash = {}; mapper.representable_attrs.each do |cfg|
      all_attributes_hash[cfg.name] = nil
    end
# FIXME: make this more obvious and beautiful!
    super Fields.new(all_attributes_hash.merge!(mapper.new(comp).to_hash))  # decorate composition and transform to hash.
  end

  # workflow methods:
  def validate(params)
    # here it would be cool to have a validator object containing the validation rules representer-like and then pass it the formed model.
    params.each do |k,v|
      send("#{k}=", v)  # this writes to <Fields>.
    end

    valid?  # this validates on <Fields>.
  end

  def save
    # DISCUSS: we should never hit @mapper here (which writes to the models) when a block is passed.
    return yield self, @comp.nested_hash_for(@mapper.new(self).to_hash) if block_given?

    @mapper.save(self)
  end

  # FIXME: make AM optional.
  require 'active_model'
  include ActiveModel::Validations

  # Keeps values of the form fields. What's in here is to be displayed in the browser!
  # we need this intermediate object to display both "original values" and new input from the form after submitting.
  class Fields < OpenStruct
  end
end

module Reform
  # Keeps composition of models and knows how to transform a plain hash into a nested hash.
  class Composition
    class << self
      def map(options)
        @options = options  # {song: [:title, :track], artist: [:name]}

        options.each do |mdl, meths|
          accessors = meths.collect { |m| [m, "#{m}="] }.flatten
          delegate *accessors, to: "@#{mdl}"
        end
      end

      def model_for_property(name)
        # FIXME: to be removed pretty soon.
        @options.each do |mdl, meths|
          return mdl if meths.include?(name.to_sym)
        end
        raise "property `#{name}` not mapped!"
      end
    end


    def nested_hash_for(attrs)
      {}.tap do |hsh|
        attrs.each do |name, val|
          obj = self.class.model_for_property(name)
          hsh[obj] ||= {}
          hsh[obj][name] = val
        end
      end
    end

    def initialize(models)
      models.each do |name, obj|
        instance_variable_set(:"@#{name}", obj)
      end
    end
  end

  require 'representable/hash'
  class Representer < Representable::Decorator
    include Representable::Hash

    def self.properties(names, *args)
      names.each do |name|
        property(name, *args)
      end
    end
  end
end