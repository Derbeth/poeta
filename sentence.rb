#!/usr/bin/ruby -w

require 'grammar'
require 'dictionary'
require 'randomized_choice'

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
	attr :frequency
	def initialize(dictionary,pattern,frequency)
		@dictionary,@pattern,@frequency = dictionary,pattern,frequency
		raise "invalid frequency: #{frequency}" if frequency < 0
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
	end

	# creates and returns a new sentence
	def write
		@pattern
	end
end

