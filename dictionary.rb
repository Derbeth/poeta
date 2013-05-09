# -*- encoding: utf-8 -*-

require './grammar'
require './word'
require './word_parser'
require './randomized_choice'

module Grammar
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
				word_stats << "#{@words[speech_part].size}x #{SpeechParts.describe(speech_part)}"
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
				counter.call(noun_as_subject_frequency(frequency,word),word)
			end
		end

		def get_random_object(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(NOUN) do |frequency, word|
				counter.call(noun_as_object_frequency(frequency,word),word)
			end
		end

		def get_random_verb_as_predicate(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(VERB) do |frequency, word|
				counter.call(verb_as_predicate_frequency(frequency,word),word)
			end
		end

		def get_random_verb_as_object(&freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(VERB) do |frequency, word|
				counter.call(verb_as_object_frequency(frequency,word),word)
			end
		end

		def get_random_adjective(noun, exclude_double=false, &freq_counter)
			counter = block_given? ? freq_counter : lambda { |freq,word| freq }
			get_random(ADJECTIVE) do |frequency, word|
				if exclude_double && word.double
					frequency = 0
				elsif word.get_property(:only_singular) && noun.number != SINGULAR
					frequency = 0
				elsif word.get_property(:only_plural) && noun.number != PLURAL
					frequency = 0
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

		# erases all contents of the dictionary and reads new contents from the given source
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
					word = Words.get_parser(speech_part).parse(word_text,gram_props,frequency,rest)
					raise ParseError, "line '#{line}' not parsed" unless word

					@words[speech_part] ||= []
					@words[speech_part] << word
				rescue ParseError => e
					puts "error: #{e.message}"
				end
			end
			validate
		end

		def each
			@words.values.each do |word_list|
				word_list.each { |e| yield e }
			end
		end

		def statistics
			stats = {}
			@words.each do |speech_part, word_list|
				stats[speech_part] = {}
				sum_freq = word_list.reduce(0) { |sum, word| sum + frequency_for_statistics(speech_part,word) }.to_f
				sum_obj_freq = nil
				count_obj_freq = has_obj_frequency_in_statistics?(speech_part)
				if count_obj_freq
					sum_obj_freq = word_list.reduce(0) { |sum, word| sum + obj_frequency_for_statistics(speech_part,word) }.to_f
				end
				word_list.each do |word|
					stats[speech_part][word] = {}
					stats[speech_part][word][:freq] = sum_freq == 0.0 ? 0.0 : frequency_for_statistics(speech_part,word).to_f/sum_freq
					if count_obj_freq
						stats[speech_part][word][:obj_freq] = sum_obj_freq == 0.0 ? 0.0 : obj_frequency_for_statistics(speech_part,word).to_f/sum_obj_freq
					end
				end
			end
			stats
		end

		def has_obj_frequency_in_statistics?(speech_part)
			speech_part == NOUN || speech_part == VERB
		end

		def frequency_for_statistics(speech_part, word)
			case speech_part
			when NOUN
				noun_as_subject_frequency(word.frequency, word)
			when VERB
				verb_as_predicate_frequency(word.frequency, word)
			else
				word.frequency
			end
		end

		def obj_frequency_for_statistics(speech_part, word)
			case speech_part
			when NOUN
				noun_as_object_frequency(word.frequency, word)
			when VERB
				verb_as_object_frequency(word.frequency, word)
			else
				word.frequency
			end
		end

		# Checks if the word is correct in context of this dictionary.
		# Does not check word type-specific constraints (for example
		# does not check if a word is a correct noun etc.), rather it
		# checks things like whether semantic properties of the word
		# make sense (for example, if the word does not require
		# existence of words not defined in the dictionary).
		#
		# The method *cannot* assume that the tested word is included
		# in the dictionary.
		#
		# The method *should not* output anything to logs.
		#
		# Returns error message or nil if the word is correct.
		def validate_word(checked_word)
			SEMANTIC_OPTS.each do |prop_str,prop|
				next if prop == :semantic
				prop_val = checked_word.get_property(prop)
				next if prop_val.nil?
				return "#{prop} without values" if prop_val.empty?

				matcher, err_msg = nil, nil
				case prop
					when :only_with, :not_with, :takes_only, :takes_no
						matcher = lambda { |w| !((w.get_property(:semantic) || []) & prop_val).empty? }
						err_msg = "no word with semantics #{prop_val.inspect}"
					when :only_with_word, :takes_only_word, :not_with_word, :takes_no_word
						matcher = lambda { |w| prop_val.include?(w.text) }
						err_msg = "no word with text #{prop_val.inspect}"
					else
						raise "unhandled semantic opt: #{prop}"
				end

				found = false
				self.each do |word|
					next if word == checked_word
					if matcher.call(word)
						found = true
						break
					end
				end

				return err_msg unless found
			end
			nil
		end

		# finds words in dictionary that don't work well with the given grammar.
		# For example, words having grammar properties that don't match the grammar rules
		# and as result the word cannot be inflected, although it seems the intention of
		# the author was to have the word inflected.
		# returns a list like
		#   [{:word => 'wrong word', :message => 'error message'}, ...]
		def validate_with_grammar(grammar)
			errors = []
			@words.each do |speech_part, list|
				list.each do |word|
					unless word.gram_props.empty? || grammar.has_rule_for?(speech_part, word.text, *word.gram_props)
						errors << {:word=>word.text,
							:message=>"#{speech_part} '#{word.text}' has no matching rule in grammar"}
					end
				end
			end
			errors
		end

		protected

		# returns index of random word or -1 if none can be selected
		def get_random_index(freq_array,speech_part)
			index = ByFrequencyChoser.choose_random_index(freq_array)
# 			puts "random #{speech_part}: #{index}"
			index
		end

		# validates the dictionary, printing warnings to standard output
		def validate
			@words.keys.sort.each do |speech_part|
				@words[speech_part].sort.each do |word|
					err_msg = validate_word(word)
					if err_msg
						puts "warn: #{speech_part} '#{word.text}' - #{err_msg}"
					end
				end
			end
		end

		private
		class FrequencyHolder
			attr_reader :frequency
			def initialize(freq)
				@frequency = freq
			end
		end

		def noun_as_subject_frequency(frequency, word)
			if word.get_property(:only_obj)
				frequency = 0
			end
			frequency
		end

		def noun_as_object_frequency(frequency, word)
			if word.get_property(:only_subj)
				frequency = 0
			elsif word.get_property(:obj_freq)
				frequency = word.get_property(:obj_freq)
			end
			frequency
		end

		def verb_as_predicate_frequency(frequency, word)
			if word.get_property(:only_obj)
				frequency = 0
			end
			frequency
		end

		def verb_as_object_frequency(frequency, word)
			if word.get_property(:obj_freq)
				frequency = word.get_property(:obj_freq)
			elsif word.get_property(:not_as_object)
				frequency = 0
			end
			frequency
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

end
