#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-

require './grammar'
require './word'
require './randomized_choice'

module Grammar
	OBJECT_ONLY = 'OO' # TODO unused
	NO_NOUN_NOUN = 'NO_NOUN_NOUN' # TODO unused

	class Dictionary
		include Enumerable

		def initialize
			@words = {}
		end

		# returns summary of number of each word type in the dictionary
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

		# gets random speech part of nil in no suitable can be found
		# you can optionally pass a block changing the way frequency of each word is counted
		#
		# like:
		#   get_ranom(NOUN) { |frequency, word| word.text.empty? ? 0 : frequency }
		#
		# a ready block is returned by semantic_chooser() method
		def get_random(speech_part, &freq_counter)
			return nil unless(@words.has_key?(speech_part))
			if block_given?
				freq_array = @words[speech_part].collect do |word|
					frequency = freq_counter.call(word.frequency, word)
					FrequencyHolder.new(frequency)
				end
			else
				freq_array = @words[speech_part]
			end
			index = get_random_index(freq_array,speech_part)
			index == -1 ? nil : @words[speech_part][index]
		end

		# returns a block to be passed to get_random() method.
		# It implements choosing words depending on their semantics.
		# ===Parameters
		# * context_word - word determining the semantic choice with its properties
		def semantic_chooser(context_word)
			context_semantics = context_word.get_property(:semantic) || []
			lambda do |frequency, word|
				if word.get_property(:only_with) && (context_semantics & word.get_property(:only_with)).empty?
					frequency = 0
				elsif word.get_property(:not_with) && !(context_semantics & word.get_property(:not_with)).empty?
					frequency = 0
				elsif word.get_property(:only_with_word) && !word.get_property(:only_with_word).include?(context_word.text)
					frequency = 0
				elsif word.get_property(:not_with_word) && word.get_property(:not_with_word).include?(context_word.text)
					frequency = 0
				elsif context_word.get_property(:takes_only) && ((word.get_property(:semantic) || []) & context_word.get_property(:takes_only)).empty?
					frequency = 0
				elsif context_word.get_property(:takes_no) && !((word.get_property(:semantic) || []) & context_word.get_property(:takes_no)).empty?
					frequency = 0
				elsif context_word.get_property(:takes_only_word) && !context_word.get_property(:takes_only_word).include?(word.text)
					frequency = 0
				elsif context_word.get_property(:takes_no_word) && context_word.get_property(:takes_no_word).include?(word.text)
					frequency = 0
				end

				frequency
			end
		end

		def get_random_subject(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(NOUN) do |frequency, word|
				if word.get_property(:only_obj)
					frequency = 0
				end
				counter.call(frequency,word)
			end
		end

		def get_random_object(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(NOUN) do |frequency, word|
				if word.get_property(:only_subj)
					frequency = 0
				elsif word.get_property(:obj_freq)
					frequency = word.get_property(:obj_freq)
				end
				counter.call(frequency,word)
			end
		end

		def get_random_verb_as_predicate(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(VERB) do |frequency, word|
				if word.get_property(:only_obj)
					frequency = 0
				end
				counter.call(frequency,word)
			end
		end

		def get_random_verb_as_object(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(VERB) do |frequency, word|
				if word.get_property(:obj_freq)
					frequency = word.get_property(:obj_freq)
				end
				counter.call(frequency,word)
			end
		end

		def get_random_adjective_object(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(ADJECTIVE) do |frequency, word|
				if word.get_property(:not_as_object)
					frequency = 0
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
			unless line =~ /^(\w)\s+/
				raise ParseError, "cannot read speech part from line '#{line}'"
			end
			speech_part,rest = $1,$'
			if !SPEECH_PARTS.include?(speech_part)
				raise ParseError, "unknown speech part #{speech_part} in line '#{line}'"
			end
			[speech_part,rest]
		end

		def read_frequency(line)
			unless line =~ /^\s*(\d+)\s+/
				raise ParseError, "cannot read frequency from '#{line}'"
			end
			frequency,rest = $1.to_i,$'
			[frequency,rest]
		end

		def read_word(line)
			word,gram_props,rest=nil,[],nil
			if line =~ /^"([^"]*)"/
				word,rest = $1,$'
			elsif line =~ /^([^\s\/]+)/
				word,rest = $1,$'
			else
				raise ParseError, "cannot read word from '#{line}'"
			end

			if rest =~ %r{^/(\w*)}
				if $1.empty?
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
		DEFAULT_MAX_SIZE = 3

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
