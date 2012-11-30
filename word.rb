#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-

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

		protected
		attr_reader :general_props

		# global_props - hash where read options will be stored
		# block - will receive split params to parse
		def self.parse(line,global_props,&block)
			line.strip! if line
			if line && !line.empty?
				semantic_opts = {'SEMANTIC'=>:semantic,
					'ONLY_WITH'=>:only_with, 'NOT_WITH'=>:not_with,
					'ONLY_WITH_W'=>:only_with_word, 'NOT_WITH_W'=>:not_with_word,
					'TAKES_ONLY'=>:takes_only, 'TAKES_NO'=>:takes_no,
					'TAKES_ONLY_W'=>:takes_only_word, 'TAKES_NO_W'=>:takes_no_word}
				escaped = []
				last_e = -1
				# ignore whitespaces inside brackets by escaping what's inside
				line.gsub!(/\([^)]+\)/) { |match| last_e +=1; escaped[last_e] = match; "$#{last_e}" }
				line.split(/\s+/).each do |part|
					catch(:process_next_part) do
						part.gsub!(/\$(\d+)/) { escaped[$1.to_i] }
						semantic_opts.each_pair do |string,name|
							if part =~ /^#{string}\(([^)]+)\)$/
								global_props[name] ||= []
								global_props[name] += $1.split(/, */)
								throw :process_next_part
							end
						end

						if block_given?
							block.call(part)
						else
							puts "warn: unknown option #{part}"
						end
					end
				end
			end
		end
	end

	class Noun < Word
		attr_reader :animate,:gender, :number, :person
		STRING2GENDER = {'m'=>MASCULINE,'n'=>NEUTER,'f'=>FEMININE}

		def initialize(text,gram_props,frequency,gender,general_props={},number=SINGULAR,person=3,animate=true,suffix=nil)
			super(text,gram_props,general_props,frequency)
			raise "invalid gender #{gender}" unless(GENDERS.include?(gender))
			raise "invalid number #{number}" unless(NUMBERS.include?(number))
			raise "invalid person #{person}" unless([1,2,3].include?(person))
			@gender,@number,@person,@animate,@suffix = gender,number,person,animate,suffix
		end

		def Noun.parse(text,gram_props,frequency,line)
			begin
				gender,number,person,animate,suffix = MASCULINE,SINGULAR,3,true,nil
				general_props = {}
				Word.parse(line,general_props) do |part|
					case part
						when /^([mfn])$/ then gender = STRING2GENDER[$1]
						when 'Pl' then number = PLURAL
						when 'nan' then animate = false
						when /^PERSON\(([^)]*)\)/
							person = Integer($1.strip)
						when /^SUFFIX\(([^)]+)\)$/
							suffix = $1
						when 'NO_ADJ' then general_props[:no_adjective] = true
						when 'ONLY_SUBJ' then general_props[:only_subj] = true
						when 'ONLY_OBJ' then general_props[:only_obj] = true
						when /^OBJ_FREQ/
							unless part =~ /^OBJ_FREQ\((\d+)\)$/
								raise "illegal format of OBJ_FREQ in #{line}"
							end
							general_props[:obj_freq] = $1.to_i
						else puts "warn: unknown option #{part}"
					end
				end
				Noun.new(text,gram_props,frequency,gender,general_props,number,person,animate,suffix)
			rescue RuntimeError, ArgumentError
				raise ParseError, "cannot parse '#{line}': #{$!.message}"
			end
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			retval = []
			[1,2].each do |number|
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
			"Noun(#{text} n=#{number})"
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

	# common exception thrown by GramObject descendants when given invalid data
	class GramObjectError < RuntimeError
	end

	class NounObject < GramObject
		attr_reader :case, :preposition

		def initialize(noun_case, preposition=nil)
			super()
			@case, @preposition, @is_noun = noun_case, preposition, true
			raise GramObjectError, "invalid case: #{noun_case}" if !CASES.include? noun_case
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
	end

	class Verb < Word
		attr_reader :objects, :reflexive

		def initialize(text,gram_props,frequency,general_props={},reflexive=false,
			objects=[],suffix=nil)

			super(text,gram_props,general_props,frequency)
			@reflexive,@objects,@suffix = reflexive,objects,suffix
		end

		def Verb.parse(text,gram_props,frequency,line)
			reflexive, suffix = false, nil
			objects = []
			general_props = {}
			Word.parse(line,general_props) do |part|
				case part
					when /^REFL(?:EXIVE|EX)?$/ then reflexive = true
					when /^INF(?:\(([^)]+)\))?$/
						objects << InfinitiveObject.new($1)
					when /^ADJ$/ then objects << AdjectiveObject.new
					when /^SUFFIX\(([^)]+)\)$/
						suffix = $1
					when /^OBJ\(([^)]+)\)$/
						opts = $1
						object_case, preposition = nil, nil
						case opts
							when /^([^,]+),(\d+)$/
								preposition = $1.strip
								object_case = Integer($2)
							when /^\d+$/
								object_case = Integer(opts)
							else
								raise ParseError, "wrong option format for #{line}: '#{part}'"
						end
						objects << NounObject.new(object_case, preposition)
					else
						puts "warn: unknown option '#{part}' for '#{text}'"
				end
			end
			Verb.new(text,gram_props,frequency,general_props,reflexive,
				objects,suffix)
		rescue VerbError, GramObjectError => e
			raise ParseError, e.message
		end

		def inflect(grammar,form)
			inflected = grammar.inflect_verb(text,form,@reflexive,*gram_props)
			inflected += ' ' + @suffix if (@suffix)
			inflected
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			retval = []
			[1,2].each do |number|
				[1,2,3].each do |person|
					retval << {:person => person, :number => number}
				end
			end
			retval << {:infinitive =>1 }
			retval
		end

		def to_s
			result = "Verb(#{text}"
			result += ' reflexive' if reflexive;
			result += ')'
			result
		end

		private
		class VerbError < RuntimeError
		end
	end

	class Adverb < Word
		def initialize(text,gram_props,frequency,general_props={})
			super(text,gram_props,general_props,frequency)
		end

		def self.parse(text,gram_props,frequency,line)
			general_props = {}
			Word.parse(line,general_props)
			Adverb.new(text,gram_props,frequency,general_props)
		end

		def to_s
			"Adverb(#{text})"
		end
	end

	class Other < Word
		def initialize(text,gram_props,frequency)
			super(text,gram_props,{},frequency)
		end

		def self.parse(text,gram_props,frequency,line)
			raise ParseError, "does not expect any grammar properties for other but got '#{gram_props}'" if !gram_props.empty?
			raise ParseError, "does not expect other properties for other but got '#{line}'" if line && line =~ /\w/
			Other.new(text,gram_props,frequency)
		end

		def to_s
			"OtherWord(#{text})"
		end
	end

	class Adjective < Word
		attr_reader :objects

		def initialize(text,gram_props,frequency,objects=[],general_props={})
			super(text,gram_props,general_props,frequency)
			if objects.size > 1
				raise AdjectiveError, "not allowed to have more than 1 object"
			end
			@objects=objects
		end

		def Adjective.parse(text,gram_props,frequency,line)
			general_props = {}
			objects = []
			Word.parse(line,general_props) do |part|
				case part
					when 'NOT_AS_OBJ' then general_props[:not_as_object] = true
					when /^OBJ\(([^)]+)\)$/
						opts = $1
						object_case, preposition = nil, nil
						case opts
							when /^([^,]+),(\d+)$/
								preposition = $1.strip
								object_case = Integer($2)
							when /^\d+$/
								object_case = Integer(opts)
							else
								raise ParseError, "wrong option format for #{line}: '#{part}'"
						end
						objects << NounObject.new(object_case, preposition)
					else puts "warn: unknown option #{part}"
				end
			end
			Adjective.new(text,gram_props,frequency,objects, general_props)
		rescue GramObjectError, AdjectiveError => e
			raise ParseError, e.message
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			retval = []
			GENDERS.each do |gender|
				[1,2].each do |number|
					[true,false].each do |animate|
						CASES.each do |gram_case|
							retval << {:case => gram_case, :number => number, :gender => gender, :animate => animate}
						end
					end
				end
			end
			retval
		end

		def inflect(grammar,form)
			return grammar.inflect_adjective(text,form,*gram_props)
		end

		def to_s
			"Adjective(#{text})"
		end

		private
		class AdjectiveError < RuntimeError
		end
	end

	class Words
		private_class_method :new
		def Words.get_class(speech_part)
			case speech_part
				when NOUN then Noun
				when VERB then Verb
				when ADJECTIVE then Adjective
				when ADVERB then Adverb
				when OTHER then Other
				else raise "unknown speech part: #{speech_part}"
			end
		end
	end
end
