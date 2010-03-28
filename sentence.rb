#!/usr/bin/ruby -w

require 'grammar'
require 'dictionary'

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
				sentence_builder = FrequencySentenceBuilder.new(@dictionary,rest,frequency)
				@sentence_builders << sentence_builder
			rescue ParseError => e
				puts "error: #{e.message}"
			end
		end
	end

	# returns the number of sentence builders
	def size
		@sentence_builders.size
	end

	private

	class ParseError < RuntimeError
	end

	def read_frequency(line)
		unless line =~ /^(\d+)\s+/:
			raise ParseError, "cannot read frequency from '#{line}'"
		end
		frequency,rest = $1.to_i,$'
		[frequency,rest]
	end

end

class SentenceBuilder
	def initialize(dictionary,pattern)
		@dictionary,@pattern = dictionary,pattern
	end

	# creates and returns a new sentence
	def write
	end
end

class FrequencySentenceBuilder < SentenceBuilder
	attr :frequency
	def initialize(dictionary,pattern,frequency)
		super(dictionary,pattern)
		@frequency = frequency
		raise "invalid frequency: #{frequency}" if frequency < 0
	end
end
