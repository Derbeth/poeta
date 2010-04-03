#!/usr/bin/ruby -w

require 'grammar'
require 'dictionary'
require 'randomized_choice'

module Sentences
	SUBJECT = 'SUBJ'
	NOUN = 'NOUN'
	ADJECTIVE = 'ADJ'
	VERB = 'VERB'
	OBJECT = 'OBJ'
	OTHER = 'OTHER'
end

class SentenceManager
	attr_reader :debug

	def initialize(dictionary,grammar,better=false,debug=false)
		@dictionary,@grammar,@better,@debug=dictionary,grammar,better,debug
		@sentence_builders=[]
	end

	def read(source)
		@sentence_builders = []
		source.each_line do |line|
			begin
				next if line =~ /^#/ || line !~ /\w/
				line.chomp!
				frequency, rest = read_frequency(line)
				sentence_builder = SentenceBuilder.new(@dictionary,@grammar,rest,frequency,@better,@debug)
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

	def initialize(dictionary,grammar,pattern,frequency,better=false,debug=false)
		@dictionary,@grammar,@pattern,@frequency,@better,@debug = dictionary,grammar,pattern,frequency,better,debug
		raise "invalid frequency: #{frequency}" if frequency < 0
		Sentence.validate_pattern(pattern)
	end

	def create_sentence
		Sentence.new(@dictionary,@grammar,@pattern.dup,@better,@debug)
	end
end

class Sentence
	attr_accessor :debug
	attr_reader :text, :subject, :other_word_chance

	def initialize(dictionary,grammar,pattern,better=false,debug=false)
		@dictionary,@grammar,@pattern,@better,@debug = dictionary,grammar,pattern.strip,better,debug
		@subject = nil
		@nouns,@verbs = {},{}
		self.other_word_chance = DEFAULT_OTHER_CHANCE
	end

	def other_word_chance=(chance)
		raise "chance should be 0.0 and 1.0, but got #{chance}" if chance < 0.0 || chance > 1.0
		@other_word_chance = chance
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
		[Sentences::ADJECTIVE, Sentences::VERB, Sentences::OBJECT].each do |part|
			pattern.scan(match_token(part)) do |full_match,options|
				noun_index = read_index(full_match,options)
				raise "undefined noun referenced from #{full_match}" unless noun_occurs.include? noun_index
			end
		end
	end

	# creates and returns a new sentence
	def write
		@text = @pattern
		@text.gsub!(match_token(Sentences::OTHER))     { handle_other($1,$2) }
		@text.gsub!(match_token(Sentences::SUBJECT))   { handle_subject($1,$2) }
		@text.gsub!(match_token(Sentences::NOUN))      { handle_noun($1,$2) }
		@text.gsub!(match_token(Sentences::ADJECTIVE)) { handle_adjective($1,$2) }
		@text.gsub!(match_token(Sentences::VERB))      { handle_verb($1,$2) }
		@text.gsub!(match_token(Sentences::OBJECT))    { handle_object($1,$2) }
		@text += ' END' if @debug
		@text.strip!
		@text.gsub!(/ {2,}/, ' ')
		@text
	end

	def subject=(s)
		@subject = s
		@nouns[1] = @subject
	end

	private

	DEFAULT_OTHER_CHANCE = 0.3
	def handle_subject(full_match,options)
		subject_index = self.class.read_index(full_match,options)
		if subject_index == 1 && @subject
			noun = @subject
		else
			noun = handle_noun_common(full_match,options)
		end
		@subject ||= noun
		noun ? noun.text : ''
	end

	def handle_noun(full_match,options)
		noun = handle_noun_common(full_match,options)
		noun ? noun.text : '' # TODO TEMP
	end

	def handle_noun_common(full_match,options)
		noun_index = self.class.read_index(full_match,options)
		noun = nil
		4.times do
			noun = @dictionary.get_random(Grammar::NOUN)
			break unless @better && @nouns.values.include?(noun)
			puts "you shit! #{noun.inspect}"
		end
		@nouns[noun_index] = noun
		noun
	end

	def handle_adjective(full_match,options)
		noun_index = self.class.read_index(full_match,options)
		raise "no noun for #{full_match}" unless @nouns.include? noun_index
		adjective = @dictionary.get_random(Grammar::ADJECTIVE)
		return '' unless adjective
		noun = @nouns[noun_index]
		form = {:case=>NOMINATIVE, :gender=>noun.gender, :number=>noun.number}
		adjective.inflect(@grammar,form)
	end

	def handle_verb(full_match,options)
		noun_index = self.class.read_index(full_match,options)
		raise "no noun for #{full_match}" unless @nouns.include? noun_index
		verb = @dictionary.get_random(Grammar::VERB)
		return '' unless verb
		@verbs[noun_index] = verb
		noun = @nouns[noun_index]
		form = {:number=>noun.number,:person=>3} # TODO TEMP
		verb.inflect(@grammar,form)
	end

	def handle_object(full_match,options)
		noun_index = self.class.read_index(full_match,options)
		verb = @verbs[noun_index]
		raise "no verb for #{full_match}" unless verb
		return '' unless verb.object_case
		object = @dictionary.get_random(Grammar::NOUN)
		return '' unless object
		preposition_part = verb.preposition ? verb.preposition + ' ' : ''
		form = {:case=>verb.object_case}
		preposition_part + object.inflect(@grammar,form)
	end

	def handle_other(full_match,options)
		draw = rand
		return '' if draw >= @other_word_chance

		other_word = @dictionary.get_random(Grammar::OTHER)
		other_word ? other_word.text : ''
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

