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
	attr_reader :debug

	def initialize(dictionary,grammar,debug=false)
		@dictionary,@grammar,@debug=dictionary,grammar,debug
		@sentence_builders=[]
	end

	def read(source)
		@sentence_builders = []
		source.each_line do |line|
			begin
				next if line =~ /^#/ || line !~ /\w/
				line.chomp!
				frequency, rest = read_frequency(line)
				sentence_builder = SentenceBuilder.new(@dictionary,@grammar,rest,frequency,debug)
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

class Sentence
	attr_accessor :subject, :debug

	def initialize(dictionary,grammar,pattern,debug=false)
		@dictionary,@grammar,@pattern,@debug = dictionary,grammar,pattern.strip,debug
		@pattern.gsub!(/ {2,}/, ' ')
		@subject = nil
		@nouns = {}
	end

	def Sentence.validate_pattern(pattern)
		noun_occurs = {}
		[Sentences::SUBJECT, Sentences::NOUN].each do |part|
			pattern.scan(match_token(part)) do |full_match,options|
				noun_index = read_index(full_match,options)
				noun_occurs[noun_index] ||= 0
				noun_occurs[noun_index] += 1
				raise "too many occurances of noun #{noun_index}" if noun_occurs[noun_index] > 1
			end
		end
		[Sentences::ADJECTIVE, Sentences::VERB].each do |part|
			pattern.scan(match_token(part)) do |full_match,options|
				noun_index = read_index(full_match,options)
				raise "undefined noun referenced from #{full_match}" unless noun_occurs.include? noun_index
			end
		end
	end

	# creates and returns a new sentence
	def write
		text = @pattern
		text.gsub!(match_token(Sentences::SUBJECT))   { handle_subject($1,$2) }
		text.gsub!(match_token(Sentences::NOUN))      { handle_noun($1,$2) }
		text.gsub!(match_token(Sentences::ADJECTIVE)) { handle_adjective($1,$2) }
		text.gsub!(match_token(Sentences::VERB))      { handle_verb($1,$2) }
		text.strip!
		text += ' END' if @debug
		text
	end

	private

	def handle_subject(full_match,options)
		noun = handle_noun_common(full_match,options)
		@subject ||= noun
		noun ? noun.text : ''
	end

	def handle_noun(full_match,options)
		noun = handle_noun_common(full_match,options)
		noun ? noun.text : '' # TODO TEMP
	end

	def handle_noun_common(full_match,options)
		noun_index = self.class.read_index(full_match,options)
		noun = @dictionary.get_random(Grammar::NOUN)
		@nouns[noun_index] = noun
		noun
	end

	def handle_adjective(full_match,options)
		noun_index = self.class.read_index(full_match,options)
		raise "no noun for #{full_match}" unless @nouns.include? noun_index
		adjective = @dictionary.get_random(Grammar::ADJECTIVE)
		return '' unless adjective
		noun = @nouns[noun_index]
		form = {:case=>NOMINATIVE, :gender=>noun.gender}
		adjective.inflect(@grammar,form)
	end

	def handle_verb(full_match,options)
		noun_index = self.class.read_index(full_match,options)
		raise "no noun for #{full_match}" unless @nouns.include? noun_index
		verb = @dictionary.get_random(Grammar::VERB)
		return '' unless verb
		noun = @nouns[noun_index]
		verb.text
	end

	def Sentence.read_index(full_match,options)
		options.strip! if options
		if options && !options.empty?:
			raise "invalid index in #{full_match}, should be number" if options !~ /^\d+$/
			return options.to_i
		end
		return 1
	end

	def Sentence.match_token(part)
		/(\$\{#{part}([^}]*)\})/
	end

	def match_token(part)
		Sentence.match_token(part)
	end
end

