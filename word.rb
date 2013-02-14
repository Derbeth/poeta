# -*- encoding: utf-8 -*-

require './parser'
require './grammar'

module Grammar
	class Word
		attr_reader :text, :gram_props, :frequency

		def initialize(text,gram_props=[],general_props={},frequency=100)
			gram_props ||= []
			@text,@frequency,@gram_props,@general_props=text,frequency,gram_props,general_props
			unless gram_props.respond_to?(:each) && gram_props.respond_to?(:size)
				raise "expect gram_props to behave like an array but got #{gram_props.inspect}"
			end
			unless general_props.respond_to?(:keys)
				raise "expect general props to behave like a hash but got #{general_props.inspect}"
			end
			if !gram_props.empty? && !gram_props[0].kind_of?(String)
				raise "gram_props should be an array of strings"
			end
			if frequency < 0
				raise "invalid frequency for #{text}: #{frequency}"
			end
		end

		def <=>(other)
			res = @text <=> other.text
			res = self.class.name <=> other.class.name if (res == 0)
			res = @gram_props <=> other.gram_props if (res == 0)
			res = @frequency <=> other.frequency if (res == 0)
			res
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			return [{}]
		end

		def inflect(grammar,form)
			return @text
		end

		def get_property(prop_name)
			@general_props[prop_name]
		end

		def get_properties
			@general_props.clone
		end

		def to_s
			"Word(#{text} p=#{@general_props.inspect})"
		end

		protected
		attr_reader :general_props
	end

	class WordValidationError < StandardError
	end

	# options: :no_adjective, :no_attribute, :no_noun_noun, :only_subj, :only_obj
	class Noun < Word
		attr_reader :animate,:gender,:number,:person,:attributes,:suffix

		def initialize(text,gram_props,frequency,gender,general_props={},number=SINGULAR,person=3,animate=true,attributes=[],suffix=nil)
			super(text,gram_props,general_props,frequency)
			raise WordValidationError, "invalid gender #{gender}" unless(GENDERS.include?(gender))
			raise WordValidationError, "invalid number #{number}" unless(NUMBERS.include?(number))
			raise WordValidationError, "invalid person #{person}" unless([1,2,3].include?(person))
			raise WordValidationError, "not allowed to have more than 1 attribute" if attributes.size > 1
			@gender,@number,@person,@animate,@attributes,@suffix = gender,number,person,animate,attributes,suffix
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			retval = []
			NUMBERS.each do |number|
				CASES.each do |gram_case|
					retval << {:case => gram_case, :number => number}
				end
			end
			retval
		end

		def inflect(grammar,form)
			form[:number] ||= @number
			inflected = grammar.inflect_noun(text,form,*gram_props)
			inflected += ' ' + @suffix if (@suffix)
			inflected
		end

		def to_s
			"Noun(#{text}#{@suffix} n=#{number})"
		end

		private
		class NounError < RuntimeError
		end
	end

	# abstract base class for grammatical object in a sentence
	class GramObject
		def initialize
			@is_noun, @is_adjective, @is_infinitive = false, false, false
		end

		def is_noun?
			@is_noun
		end

		def is_adjective?
			@is_adjective
		end

		def is_infinitive?
			@is_infinitive
		end
	end

	class NounObject < GramObject
		attr_reader :case, :preposition

		def initialize(noun_case, preposition=nil)
			super()
			@case, @preposition, @is_noun = noun_case, preposition, true
			raise WordValidationError, "invalid case: #{noun_case}" if !CASES.include? noun_case
		end

		def to_s
			res = "NounObject(#{CASE2STRING[@case]}"
			res += ", prep=#{@preposition}" if @preposition
			res + ")"
		end
	end

	class AdjectiveObject < GramObject
		def initialize
			super()
			@is_adjective = true
		end
	end

	class InfinitiveObject < GramObject
		attr_reader :preposition

		def initialize(preposition=nil)
			super()
			@preposition, @is_infinitive = preposition, true
		end

		def to_s
			"InfObject(#{preposition})"
		end
	end

	# Can have properties: :only_obj, :not_as_object
	class Verb < Word
		attr_reader :objects, :reflexive

		def initialize(text,gram_props,frequency,general_props={},reflexive=false,
			objects=[],suffix=nil)

			super(text,gram_props,general_props,frequency)
			@reflexive,@objects,@suffix = reflexive,objects,suffix
		end

		def inflect(grammar,form)
			inflected = grammar.inflect_verb(text,form,@reflexive,*gram_props)
			inflected += ' ' + @suffix if (@suffix)
			inflected
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			retval = []
			[false, true].each do |imperative|
				NUMBERS.each do |number|
					PERSONS.each do |person|
						form = {:person => person, :number => number}
						form[:imperative] = true if imperative
						retval << form
					end
				end
			end
			retval << {:infinitive =>true }
			retval
		end

		def to_s
			result = "Verb(#{text}"
			result += ' reflexive' if reflexive;
			result += ')'
			result
		end
	end

	class Adverb < Word
		def initialize(text,gram_props,frequency,general_props={})
			super(text,gram_props,general_props,frequency)
		end

		def to_s
			"Adverb(#{text})"
		end
	end

	class Other < Word
		def initialize(text,gram_props,frequency)
			super(text,gram_props,{},frequency)
		end

		def to_s
			"OtherWord(#{text})"
		end
	end

	# Also can have properties: :not_as_object, :only_singular, :only_plural
	class Adjective < Word
		attr_reader :attributes, :double

		def initialize(text,gram_props,frequency,double=false,attributes=[],general_props={},suffix=nil)
			super(text,gram_props,general_props,frequency)
			if attributes.size > 1
				raise WordValidationError, "not allowed to have more than 1 attribute"
			end
			@attributes,@double,@suffix=attributes,double,suffix
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			retval = []
			GENDERS.each do |gender|
				[true, false].each do |animate|
					NUMBERS.each do |number|
						CASES.each do |gram_case|
							form = {:case => gram_case, :number => number, :gender => gender}
							if gender == MASCULINE
								retval << form.merge({:animate => animate})
							else
								retval << form if animate
							end
						end
					end
				end
			end
			retval
		end

		def inflect(grammar,form)
			inflected = grammar.inflect_adjective(text,form,*gram_props)
			inflected += ' ' + @suffix if (@suffix)
			inflected
		end

		def to_s
			"Adjective(#{text}#{@suffix})"
		end
	end
end
