#!/usr/bin/ruby -w

require 'grammar'
require 'dictionary'
require 'randomized_choice'

module Sentences
	SUBJECT = 'SUBJ'
	NOUN = 'NOUN'
	ADJECTIVE = 'ADJ'
	VERB = 'VERB'
end

class SentenceManager
	def initialize(dictionary)
		@dictionary=dictionary
		@sentence_builders=[]
	end

	def read(source)
		@sentence_builders = []
		source.each_line do |line|
			begin
				next if line =~ /^#/ || line !~ /\w/
				line.chomp!
				frequency, rest = read_frequency(line)
				sentence_builder = SentenceBuilder.new(@dictionary,rest,frequency)
				@sentence_builders << sentence_builder
			rescue ParseError => e
				puts "error: #{e.message}"
			end
		end
	end

	# gets a random sentence or nil if no choice
	def random_sentence
		ByFrequencyChoser.choose_random(@sentence_builders).create_sentence
	end

	# returns the number of sentence builders
	def size
		@sentence_builders.size
	end

	private

	class ParseError < RuntimeError
	end

	def read_frequency(line)
		unless line =~ /^\s*(\d+)\s+/:
			raise ParseError, "cannot read frequency from '#{line}'"
		end
		frequency,rest = $1.to_i,$'
		[frequency,rest]
	end

end

class SentenceBuilder
	include Sentences
	attr :frequency
	def initialize(dictionary,pattern,frequency)
		@dictionary,@pattern,@frequency = dictionary,pattern,frequency
		raise "invalid frequency: #{frequency}" if frequency < 0
		validate_pattern
	end

	def validate_pattern
		subjects_count = 0
		@pattern.scan(SUBJECT) { subjects_count += 1 }
		raise "more than one subject in '#@pattern'" if subjects_count > 1
	end

	def create_sentence
		Sentence.new(@dictionary,@pattern)
	end
end

class Sentence
	attr_reader :subject
	attr_writer :subject
	def initialize(dictionary,pattern)
		@dictionary,@pattern = dictionary,pattern
		@subject = nil
		@nouns = {}
	end

	# creates and returns a new sentence
	def write
		text = @pattern
		text.gsub!(match_token(Sentences::SUBJECT)) { handle_subject($1,$2) }
		text.gsub!(match_token(Sentences::NOUN))    { handle_noun($1,$2) }
		text
	end

	private

	def handle_subject(full_match,options)
		unless @subject:
			@subject = handle_noun_common(full_match,options)
		end
		@subject.text
	end

	def handle_noun(full_match,options)
		handle_noun_common(full_match,options).text # TODO TEMP
	end

	def handle_noun_common(full_match,options)
		noun_index = 1
		options.strip! if options
		if options && !options.empty?:
			raise "invalid index in #{full_match}, should be number" if options !~ /^\d+$/
			noun_index = options.to_i
		end
		noun = @dictionary.get_random(Grammar::NOUN)
# 		puts "chose noun #{noun.object_id} in sentence #{self.object_id}"
		@nouns[noun_index] = noun
		noun
	end

	def match_token(part)
		/(\$\{#{part}([^}]*)\})/
	end
end

