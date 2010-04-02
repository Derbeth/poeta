#!/usr/bin/ruby -w

require 'grammar'
require 'randomized_choice'

module Grammar
	OBJECT_ONLY = 'OO'
	NO_NOUN_NOUN = 'NO_NOUN_NOUN'

	class Word
		attr_reader :text, :gram_props, :frequency

		def initialize(text,gram_props=[],frequency=100)
			gram_props ||= []
			@text,@frequency,@gram_props=text,frequency,gram_props
			unless gram_props.respond_to?(:each) && gram_props.respond_to?(:size):
				raise "expect gram_props to behave like an array but got #{gram_props.inspect}"
			end
			if !gram_props.empty? && !gram_props[0].kind_of?(String):
				raise "gram_props should be an array of strings"
			end
			if frequency < 0:
				raise "invalid frequency for #{text}: #{frequency}"
			end
			if text == '':
				raise "word text is empty"
			end
		end

		def <=>(other)
			@text <=> other.text
		end

		def all_forms
			return [{}]
		end

		def inflect(grammar,form)
			return @text
		end
	end

	class Noun < Word
		attr_reader :gender
		STRING2GENDER = {'m'=>MASCULINE,'n'=>NEUTER,'f'=>FEMININE}

		def initialize(text,gram_props,frequency,gender)
			super(text,gram_props,frequency)
			@gender = gender
			raise "invalid gender #{gender}" unless(GENDERS.include?(gender))
		end

		def Noun.parse(text,gram_props,frequency,line)
			gender = MASCULINE
			if line =~ /\b([mfn])\b/
				gender = STRING2GENDER[$1]
			end
			Noun.new(text,gram_props,frequency,gender)
		end

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
			return grammar.inflect_noun(text,form,*gram_props)
		end
	end

	class Verb < Word
		def initialize(text,gram_props,frequency,preposition,object)
			super(text,gram_props,frequency)
		end

		def Verb.parse(text,gram_props,frequency,line)
			Verb.new(text,gram_props,frequency,'','') # TODO TEMP
		end
	end

	class Adjective < Word
		def initialize(text,gram_props,frequency)
			super(text,gram_props,frequency)
		end

		def Adjective.parse(text,gram_props,frequency,line)
			Adjective.new(text,gram_props,frequency) # TODO TEMP
		end

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
			retval = 'Dictionary; '
			word_stats = []
			@words.keys.sort.each do |speech_part|
				word_stats << "#{@words[speech_part].size}x #{Grammar.describe_speech_part(speech_part)}"
			end
			retval += word_stats.join(', ')
		end

		def get_random(speech_part)
			index = get_random_index(speech_part)
			index == -1 ? nil : @words[speech_part][index]
		end

		def read(source)
			source.each_line do |line|
				begin
					next if line =~ /^#/ || line !~ /\w/
					line.chomp!
					speech_part, rest = read_speech_part(line)
					frequency, rest = read_frequency(rest)
					word_text, gram_props, rest = read_word(rest)
					word = Words.get_class(speech_part).parse(word_text,gram_props,frequency,rest)

					@words[speech_part] ||= []
					@words[speech_part] << word
# 					puts "#{word.inspect}"
				rescue DictParseError => e
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

		class DictParseError < RuntimeError
		end

		# returns index of random word or -1 if none can be selected
		def get_random_index(speech_part)
			return -1 unless(@words.has_key?(speech_part))
			index = ByFrequencyChoser.choose_random_index(@words[speech_part])
# 			puts "random #{speech_part}: #{index}"
			index
		end

		private

		def read_speech_part(line)
			unless line =~ /^(\w)\s+/:
				raise DictParseError, "cannot read speech part from line '#{line}'"
			end
			speech_part,rest = $1,$'
			if !SPEECH_PARTS.include?(speech_part):
				raise DictParseError, "unknown speech part #{speech_part} in line '#{line}'"
			end
			[speech_part,rest]
		end

		def read_frequency(line)
			unless line =~ /^\s*(\d+)\s+/:
				raise DictParseError, "cannot read frequency from '#{line}'"
			end
			frequency,rest = $1.to_i,$'
			[frequency,rest]
		end

		def read_word(line)
			word,gram_props,rest=nil,[],nil
			if line =~ /^"([^"]+)"/:
				word,rest = $1,$'
			elsif line =~ /^([^\s\/]+)/:
				word,rest = $1,$'
			else
				raise DictParseError, "cannot read word from '#{line}'"
			end

			if rest =~ %r{^/(\w*)}:
				if $1.empty?:
					raise DictParseError, "cannot read word gram props from '#{line}'"
				end
				gram_props,rest = $1.split(//),$'
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
		DEFAULT_MAX_TRIES = 4
		DEFAULT_MAX_SIZE = 2

		# returns index of random word or -1 if none can be selected
		def get_random_index(speech_part)
			@remembered_indices ||= {}
			@remembered_indices[speech_part] ||= []
			index = nil
			DEFAULT_MAX_TRIES.times do
				index = super(speech_part)
				break unless @remembered_indices[speech_part].include?(index)
			end
			@remembered_indices[speech_part].push(index)
			@remembered_indices[speech_part].shift if @remembered_indices[speech_part].size > @max_size
			index
		end
	end

end
