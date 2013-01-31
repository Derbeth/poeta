# -*- encoding: utf-8 -*-

require './parser'
require './grammar'

module Grammar
	SEMANTIC_OPTS = {'SEMANTIC'=>:semantic,
		'ONLY_WITH'=>:only_with, 'NOT_WITH'=>:not_with,
		'ONLY_WITH_W'=>:only_with_word, 'NOT_WITH_W'=>:not_with_word,
		'TAKES_ONLY'=>:takes_only, 'TAKES_NO'=>:takes_no,
		'TAKES_ONLY_W'=>:takes_only_word, 'TAKES_NO_W'=>:takes_no_word}

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

	# exception to be thrown from parsers to the classes outside the module
	class ParseError < StandardError
	end

	class WordParser
		def parse(text,gram_props,frequency,line)
			raise 'unimplemented'
		end

		protected

		# global_props - hash where read options will be stored
		def handle_option(opt_name, opt_params, general_props)
			SEMANTIC_OPTS.each_pair do |name, store_key|
				if name == opt_name
					general_props[store_key] ||= []
					general_props[store_key] += opt_params
					return
				end
			end

			puts "warn: unknown option #{opt_name}"
		end

		def parse_noun_object(opt_name, opt_params)
			object_case, preposition = nil, nil
			case opt_params.size
				when 2
					preposition = opt_params[0]
					object_case = Integer(opt_params[1])
				when 1
					object_case = Integer(opt_params[0])
				else
					raise WordParserError, "wrong format for #{opt_name}"
			end
			NounObject.new(object_case, preposition)
		end

		# throws an exception if parsed option has any parameters
		def assert_no_params(opt_name, opt_params)
			raise WordParserError, "#{opt_name} takes no parameters" if opt_params != nil
		end

		# throws an exception if parsed option has number of parameters different than given
		def assert_params_count(count, opt_name, opt_params)
			raise WordParserError, "#{opt_name} expects #{count} params" if opt_params.nil? || opt_params.size != count
		end

		def new_parser
			Poeta::Parser.new
		end

		class WordParserError < RuntimeError
		end
	end

	class NounParser < WordParser
		def parse(text,gram_props,frequency,line)
			gender,number,person,animate,suffix = MASCULINE,SINGULAR,3,true,nil
			general_props = {}
			attributes = []

			new_parser.parse(line).each_option do |opt_name, opt_params|
				case opt_name
					when /^([mfn])$/
						assert_no_params(opt_name, opt_params)
						gender = STRING2GENDER[opt_name]
					when 'Pl'
						assert_no_params(opt_name, opt_params)
						number = PLURAL
					when 'nan'
						assert_no_params(opt_name, opt_params)
						animate = false
					when 'PERSON'
						assert_params_count(1, opt_name, opt_params)
						person = Integer(opt_params[0])
					when 'SUFFIX'
						assert_params_count(1, opt_name, opt_params)
						suffix = opt_params[0]
					when 'NO_ADJ'
						assert_no_params(opt_name, opt_params)
						general_props[:no_adjective] = true
					when 'NO_NOUN_NOUN'
						assert_no_params(opt_name, opt_params)
						general_props[:no_noun_noun] = true
					when 'NO_ATTR'
						assert_no_params(opt_name, opt_params)
						general_props[:no_attribute] = true
					when 'ONLY_SUBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:only_subj] = true
					when 'ONLY_OBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:only_obj] = true
					when 'OBJ_FREQ'
						assert_params_count(1, opt_name, opt_params)
						general_props[:obj_freq] = Integer(opt_params[0])
					when 'ATTR'
						attributes << parse_noun_object(opt_name, opt_params)
					else
						handle_option(opt_name, opt_params, general_props)
				end
			end
			Noun.new(text,gram_props,frequency,gender,general_props,number,person,animate,attributes,suffix)
		rescue WordParserError, WordValidationError, ArgumentError
			raise ParseError, "cannot parse '#{line}': #{$!.message}"
		end

		private
		STRING2GENDER = {'m'=>MASCULINE,'n'=>NEUTER,'f'=>FEMININE}
	end

	class VerbParser < WordParser
		def parse(text,gram_props,frequency,line)
			reflexive, suffix = false, nil
			objects = []
			general_props = {}
			new_parser.parse(line).each_option do |opt_name, opt_params|
				case opt_name
					when /^REFL(?:EXIVE|EX)?$/
						assert_no_params(opt_name, opt_params)
						reflexive = true
					when 'INF'
						if opt_params.nil?
							objects << InfinitiveObject.new
						elsif opt_params.size == 1
							objects << InfinitiveObject.new(opt_params[0])
						else
							raise WordParserError, "invalid format of #{opt_name}"
						end
					when 'ADJ'
						assert_no_params(opt_name, opt_params)
						objects << AdjectiveObject.new
					when 'SUFFIX'
						assert_params_count(1, opt_name, opt_params)
						suffix = opt_params[0]
					when 'OBJ_FREQ'
						assert_params_count(1, opt_name, opt_params)
						general_props[:obj_freq] = Integer(opt_params[0])
					when 'OBJ'
						objects << parse_noun_object(opt_name, opt_params)
					when 'ONLY_OBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:only_obj] = true
					when 'NOT_AS_OBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:not_as_object] = true
					else
						handle_option(opt_name, opt_params, general_props)
				end
			end
			Verb.new(text,gram_props,frequency,general_props,reflexive,
				objects,suffix)
		rescue WordParserError, WordValidationError, ArgumentError
			raise ParseError, "cannot parse '#{line}': #{$!.message}"
		end
	end

	class AdjectiveParser < WordParser
		def parse(text,gram_props,frequency,line)
			general_props = {}
			double = false
			attributes = []
			suffix = nil
			new_parser.parse(line).each_option do |opt_name, opt_params|
				case opt_name
					when 'NOT_AS_OBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:not_as_object] = true
					when 'DOUBLE'
						assert_no_params(opt_name, opt_params)
						double = true
					when 'POSS'
						assert_no_params(opt_name, opt_params)
						double = true
					when 'ONLY_SING'
						assert_no_params(opt_name, opt_params)
						general_props[:only_singular] = true
					when 'ONLY_PL'
						assert_no_params(opt_name, opt_params)
						general_props[:only_plural] = true
					when 'SUFFIX'
						assert_params_count(1, opt_name, opt_params)
						suffix = opt_params[0]
					when 'ATTR'
						attributes << parse_noun_object(opt_name, opt_params)
					else
						handle_option(opt_name, opt_params, general_props)
				end
			end
			Adjective.new(text,gram_props,frequency,double,attributes,general_props,suffix)
		rescue WordParserError, WordValidationError
			raise ParseError, "cannot parse '#{line}': #{$!.message}"
		end
	end

	class AdverbParser < WordParser
		def parse(text,gram_props,frequency,line)
			general_props = {}
			new_parser.parse(line).each_option do |opt_name, opt_params|
				handle_option(opt_name, opt_params, general_props)
			end
			Adverb.new(text,gram_props,frequency,general_props)
		end
	end

	class OtherParser < WordParser
		def parse(text,gram_props,frequency,line)
			raise ParseError, "does not expect any grammar properties for other but got '#{gram_props}'" if !gram_props.empty?
			raise ParseError, "does not expect other properties for other but got '#{line}'" if line && line =~ /\w/
			Other.new(text,gram_props,frequency)
		end
	end

	# options: :no_adjective, :no_attribute, :no_noun_noun, :only_subj, :only_obj
	class Noun < Word
		attr_reader :animate,:gender, :number, :person,:attributes

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

	# utility class
	class Words
		private_class_method :new
		def Words.get_parser(speech_part)
			parser_class = case speech_part
				when NOUN then NounParser
				when VERB then VerbParser
				when ADJECTIVE then AdjectiveParser
				when ADVERB then AdverbParser
				when OTHER then OtherParser
				else raise "unknown speech part: #{speech_part}"
			end
			parser_class.new
		end
	end
end
