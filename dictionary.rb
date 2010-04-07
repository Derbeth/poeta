#!/usr/bin/ruby -w

require 'grammar'
require 'randomized_choice'

module Grammar
	OBJECT_ONLY = 'OO'
	NO_NOUN_NOUN = 'NO_NOUN_NOUN'

	class Word
		attr_reader :text, :gram_props, :frequency

		def initialize(text,gram_props=[],general_props={},frequency=100)
			gram_props ||= []
			@text,@frequency,@gram_props,@general_props=text,frequency,gram_props,general_props
			unless gram_props.respond_to?(:each) && gram_props.respond_to?(:size):
				raise "expect gram_props to behave like an array but got #{gram_props.inspect}"
			end
			unless general_props.respond_to?(:keys)
				raise "expect general props to behave like a hash but got #{general_props.inspect}"
			end
			if !gram_props.empty? && !gram_props[0].kind_of?(String):
				raise "gram_props should be an array of strings"
			end
			if frequency < 0:
				raise "invalid frequency for #{text}: #{frequency}"
			end
		end

		def <=>(other)
			@text <=> other.text
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
	end

	class Noun < Word
		attr_reader :gender, :number, :person
		STRING2GENDER = {'m'=>MASCULINE,'n'=>NEUTER,'f'=>FEMININE}

		def initialize(text,gram_props,general_props,frequency,gender,number=SINGULAR,person=3)
			super(text,gram_props,general_props,frequency)
			raise "invalid gender #{gender}" unless(GENDERS.include?(gender))
			raise "invalid number #{number}" unless(NUMBERS.include?(number))
			raise "invalid person #{person}" unless([1,2,3].include?(person))
			@gender,@number,@person = gender,number,person
		end

		def Noun.parse(text,gram_props,frequency,line)
			begin
				gender,number,person = MASCULINE,SINGULAR,3
				line.strip! if line
				general_props = {}
				if line && !line.empty?
					line.split(/\s+/).each do |part|
						case part
							when /^([mfn])$/ then gender = STRING2GENDER[$1]
							when 'Pl' then number = PLURAL
							when /^PERSON\(([^)]*)\)/
								person = Integer($1.strip)
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
				end
				Noun.new(text,gram_props,general_props,frequency,gender,number,person)
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
			return grammar.inflect_noun(text,form,*gram_props)
		end
	end

	class Verb < Word
		attr_reader :reflexive, :preposition, :object_case

		def initialize(text,gram_props,frequency,reflexive=false,preposition=nil,object_case=nil)
			super(text,gram_props,{},frequency)
			raise VerbError, "invalid case: #{object_case}" if object_case && !CASES.include?(object_case)
			@reflexive,@preposition,@object_case = reflexive,preposition,object_case
		end

		def Verb.parse(text,gram_props,frequency,line)
			reflexive = false
			preposition,object_case = nil,nil
			line.strip! if line
			if line && !line.empty?
				line.split(/\s+/).each do |part|
					case part
						when /^REFL(?:EXIVE|EX)?$/ then reflexive = true
						when /^OBJ\(([^)]+)\)$/
							opts = $1
							case opts
								when /^([^,]+),(\d+)$/
									preposition,object_case = $1.strip,Integer($2)
								when /^\d+$/
									preposition,object_case = nil,Integer(opts)
								else
									raise ParseError, "wrong option format for #{text}: '#{part}'"
							end
						else
							puts "warn: unknown option '#{part}' for '#{text}'"
					end
				end
			end
			begin
				Verb.new(text,gram_props,frequency,reflexive,preposition,object_case)
			rescue VerbError => e
				raise ParseError, e.message
			end
		end

		def inflect(grammar,form)
			grammar.inflect_verb(text,form,@reflexive,*gram_props)
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			retval = []
			[1,2].each do |number|
				[1,2,3].each do |person|
					retval << {:person => person, :number => number}
				end
			end
			retval
		end

		private
		class VerbError < RuntimeError
		end
	end

	class Adverb < Word
		def initialize(text,gram_props,frequency)
			super(text,gram_props,{},frequency)
		end

		def self.parse(text,gram_props,frequency,line)
			Adverb.new(text,gram_props,frequency)
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
	end

	class Adjective < Word
		def initialize(text,gram_props,frequency)
			super(text,gram_props,{},frequency)
		end

		def Adjective.parse(text,gram_props,frequency,line)
			Adjective.new(text,gram_props,frequency) # TODO TEMP
		end

		# returns an Enumerable collection of all applicable grammar forms
		def all_forms
			retval = []
			GENDERS.each do |gender|
				[1,2].each do |number|
					CASES.each do |gram_case|
						retval << {:case => gram_case, :number => number, :gender=> gender}
					end
				end
			end
			retval
		end

		def inflect(grammar,form)
			return grammar.inflect_adjective(text,form,*gram_props)
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

	class Dictionary
		include Enumerable

		def initialize
			@words = {}
		end

		def to_s
			retval = 'Dictionary'
			word_stats = []
			@words.keys.sort.each do |speech_part|
				word_stats << "#{@words[speech_part].size}x #{Grammar.describe_speech_part(speech_part)}"
			end
			words_part = word_stats.join(', ')
			retval += '; ' + words_part unless (words_part.empty?)
			retval
		end

		def get_random(speech_part, &freq_counter)
			return nil unless(@words.has_key?(speech_part))
			if block_given?
				freq_array = @words[speech_part].collect do |word|
					frequency = freq_counter.call(word)
					FrequencyHolder.new(frequency)
				end
			else
				freq_array = @words[speech_part]
			end
			index = get_random_index(freq_array,speech_part)
			index == -1 ? nil : @words[speech_part][index]
		end

		def get_random_subject(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(NOUN) do |word|
				if word.get_property(:only_obj)
					frequency = 0
				else
					frequency = word.frequency
				end
				counter.call(frequency,word)
			end
		end

		def get_random_object(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(NOUN) do |word|
				if word.get_property(:only_subj)
					frequency = 0
				elsif word.get_property(:obj_freq)
					frequency = word.get_property(:obj_freq)
				else
					 frequency = word.frequency
				end
				counter.call(frequency,word)
			end
		end

		def read(source)
			@words = {}
			source.each_line do |line|
				begin
					line.gsub!(/#.*/, '')
					next if line !~ /\w/
					line.chomp!
					speech_part, rest = read_speech_part(line)
					frequency, rest = read_frequency(rest)
					word_text, gram_props, rest = read_word(rest)
					word = Words.get_class(speech_part).parse(word_text,gram_props,frequency,rest)
					raise ParseError, "line '#{line}' not parsed" unless word

					@words[speech_part] ||= []
					@words[speech_part] << word
# 					puts "#{word.inspect}"
				rescue ParseError => e
					puts "error: #{e.message}"
				end
			end
		end

		def each
			@words.values.each do |word_list|
				word_list.each { |e| yield e }
			end
		end

		protected

		# returns index of random word or -1 if none can be selected
		def get_random_index(freq_array,speech_part)
			index = ByFrequencyChoser.choose_random_index(freq_array)
# 			puts "random #{speech_part}: #{index}"
			index
		end

		private
		class FrequencyHolder
			attr_reader :frequency
			def initialize(freq)
				@frequency = freq
			end
		end

		def read_speech_part(line)
			unless line =~ /^(\w)\s+/:
				raise ParseError, "cannot read speech part from line '#{line}'"
			end
			speech_part,rest = $1,$'
			if !SPEECH_PARTS.include?(speech_part):
				raise ParseError, "unknown speech part #{speech_part} in line '#{line}'"
			end
			[speech_part,rest]
		end

		def read_frequency(line)
			unless line =~ /^\s*(\d+)\s+/:
				raise ParseError, "cannot read frequency from '#{line}'"
			end
			frequency,rest = $1.to_i,$'
			[frequency,rest]
		end

		def read_word(line)
			word,gram_props,rest=nil,[],nil
			if line =~ /^"([^"]*)"/:
				word,rest = $1,$'
			elsif line =~ /^([^\s\/]+)/:
				word,rest = $1,$'
			else
				raise ParseError, "cannot read word from '#{line}'"
			end

			if rest =~ %r{^/(\w*)}:
				if $1.empty?:
					raise ParseError, "cannot read word gram props from '#{line}'"
				end
				rest=$'
				gram_props = $1.split(//)
			end
			[word,gram_props,rest]
		end
	end

	class SmartRandomDictionary < Dictionary
		def initialize(max_size=DEFAULT_MAX_SIZE)
			super()
			@max_size=max_size
		end

		protected
		DEFAULT_MAX_TRIES = 5
		DEFAULT_MAX_SIZE = 2

		# returns index of random word or -1 if none can be selected
		def get_random_index(freq_array,speech_part)
			@remembered_indices ||= {}
			@remembered_indices[speech_part] ||= []
			index = nil
			DEFAULT_MAX_TRIES.times do
				index = super(freq_array,speech_part)
				break unless @remembered_indices[speech_part].include?(index)
			end
			@remembered_indices[speech_part].push(index)
			@remembered_indices[speech_part].shift if @remembered_indices[speech_part].size > @max_size
			index
		end
	end

end
