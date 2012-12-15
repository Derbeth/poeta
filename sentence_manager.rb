# -*- encoding: utf-8 -*-

require './sentence'

class SentenceManager
	attr_reader :debug

	def initialize(dictionary,grammar,debug=false)
		@dictionary,@grammar,@debug=dictionary,grammar,debug
		@sentence_builders=[]
	end

	def read(source)
		@sentence_builders = []
		source.each_line do |line|
			begin
				line.gsub!(/#.*/, '')
				next if line !~ /\w/
				line.chomp!
				frequency, rest = read_frequency(line)
				sentence_builder = SentenceBuilder.new(@dictionary,@grammar,rest,frequency,@debug)
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

	def debug=(d)
		@debug=d
		@sentence_builders.each { |b| b.debug=d }
	end

	private

	class ParseError < SentenceError
	end

	def read_frequency(line)
		unless line =~ /^\s*(\d+)\s+/
			raise ParseError, "cannot read frequency from '#{line}'"
		end
		frequency,rest = $1.to_i,$'
		[frequency,rest]
	end

end

class SentenceBuilder
	include Sentences
	attr_accessor :frequency, :debug

	def initialize(dictionary,grammar,pattern,frequency,debug=false)
		@dictionary,@grammar,@pattern,@frequency,@debug = dictionary,grammar,pattern,frequency,debug
		raise "invalid frequency: #{frequency}" if frequency < 0
		Sentence.validate_pattern(pattern)
	end

	def create_sentence
		Sentence.new(@dictionary,@grammar,@pattern.dup,@debug)
	end
end
