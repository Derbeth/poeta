#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-

require './grammar'
require './dictionary'
require './randomized_choice'

module Sentences
	SUBJECT = 'SUBJ'
	NOUN = 'NOUN'
	ADJECTIVE = 'ADJ'
	VERB = 'VERB'
	OBJECT = 'OBJ'
	ADVERB = 'ADV'
	OTHER = 'OTHER'
end

# Ruby 1.8 had a broken handling of unicode, so ljust() did not work with accented characters
class String
	if "".respond_to? :force_encoding
		# Ruby >= 1.9 - works just fine
		alias_method :fixed_ljust, :ljust
	else
		# nasty hack for Ruby < 1.9
		def fixed_ljust(width)
		result = ljust(width)
		two_byte_chars_count = 0
		scan(/[ąćęłóńśżźßöäü]/) { two_byte_chars_count += 1 }
		two_byte_chars_count /= 2
		result + ' ' * two_byte_chars_count
		end
	end
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
				line.gsub!(/#.*/, '')
				next if line !~ /\w/
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
	attr_reader :text, :subject, :other_word_chance, :pattern

	def initialize(dictionary,grammar,pattern,better=false,debug=false)
		@dictionary,@grammar,@pattern,@better,@debug = dictionary,grammar,pattern.strip,better,debug
		@subject = nil
		@forced_subject_number = nil
		@nouns,@verbs = {},{}
		@verbs_text = {}
		self.other_word_chance = DEFAULT_OTHER_CHANCE
	end

	def other_word_chance=(chance)
		raise "chance should be 0.0 and 1.0, but got #{chance}" if chance < 0.0 || chance > 1.0
		@other_word_chance = chance
	end

	def Sentence.validate_pattern(pattern)
		noun_occurs = {}
		[Sentences::SUBJECT, Sentences::NOUN].each do |part|
			pattern.scan(match_token(part)) do |full_match,index,options|
				noun_index = read_index(full_match,index)
				noun_occurs[noun_index] ||= 0
				noun_occurs[noun_index] += 1
			end
		end
		[Sentences::VERB, Sentences::ADJECTIVE, Sentences::OBJECT].each do |part|
			pattern.scan(match_token(part)) do |full_match,index,options|
				noun_index = read_index(full_match,index)
				if part == Sentences::VERB
					parsed = parse_verb_options(options)
					if parsed[:form]
						noun_occurs[noun_index] ||= 0
						noun_occurs[noun_index] += 1
						next
					end
				end
				raise "undefined noun referenced from #{full_match} in '#{pattern}'" unless noun_occurs.include? noun_index
			end
		end
	end

	# creates and returns a new sentence
	def write
		@text = @pattern.clone
		@text.gsub!(match_token(Sentences::OTHER))     { handle_other($1,$2,$3) }
		@text.gsub!(match_token(Sentences::SUBJECT))   { handle_subject($1,$2,$3) }
		@text.gsub!(match_token(Sentences::NOUN))      { handle_noun($1,$2,$3) }
		@text.gsub!(match_token(Sentences::ADJECTIVE)) { handle_adjective($1,$2,$3) }
		@text.gsub!(match_token(Sentences::VERB))      { handle_verb($1,$2,$3) }
		@text.gsub!(match_token(Sentences::OBJECT))    { handle_object($1,$2,$3) }
		@text.gsub!(match_token(Sentences::ADVERB))    { handle_adverb($1,$2,$3) }
# 		@text += ' END' if @debug
		@text.strip!
		@text.gsub!(/ {2,}/, ' ')
		@text.gsub!(/ +([.?!,])/, '\1')
		@text = @text.fixed_ljust(40) + "| #{@pattern}" if debug
		@text
	end

	def subject=(s)
		@subject = s
		@nouns[1] = @subject
	end

	private

	DEFAULT_OTHER_CHANCE = 0.3
	def handle_subject(full_match,index,options)
		subject_index = self.class.read_index(full_match,index)
		parsed_opts = self.class.parse_common_noun_options(options)
		if subject_index == 1 && @subject
			noun = @subject
		else
			semantic_chooser = parsed_opts[:context_props] ?
				@dictionary.semantic_chooser(Word.new('', [], parsed_opts[:context_props])) :
				nil
			noun = @dictionary.get_random_subject do |counted_frequency,word|
				new_frequency = if parsed_opts[:not_empty] && word.text.empty?
					0
				elsif parsed_opts[:empty] && !word.text.empty?
					0
				elsif parsed_opts[:ignore_only]
					word.frequency
				else
					counted_frequency
				end
				if semantic_chooser
					semantic_chooser.call(new_frequency,word)
				else
					new_frequency
				end
			end
			noun_index = self.class.read_index(full_match,index)
			@nouns[noun_index] = noun
		end
		@subject ||= noun
		return '' unless noun
		gram_case = parsed_opts[:case] || NOMINATIVE
		form = {:case=>gram_case}
		noun.inflect(@grammar,form)
	end

	def handle_noun(full_match,index,options)
		noun_index = self.class.read_index(full_match,index)
		parsed_opts = self.class.parse_common_noun_options(options)

		semantic_chooser = parsed_opts[:context_props] ?
			@dictionary.semantic_chooser(Word.new('', [], parsed_opts[:context_props])) :
			nil

		noun = @dictionary.get_random(Grammar::NOUN) do |frequency, word|
			if word.text.empty?
				0
			elsif semantic_chooser
				semantic_chooser.call(frequency,word)
			else
				frequency
			end
		end

		@nouns[noun_index] = noun
		return '' unless noun
		gram_case = parsed_opts[:case] || NOMINATIVE
		form = {:case=>gram_case}
		noun.inflect(@grammar,form)
	end

	def handle_adjective(full_match,index,options)
		noun_index = self.class.read_index(full_match,index)
		parsed_opts = self.class.parse_adjective_options(options)
		raise "no noun for #{full_match}" unless @nouns.include? noun_index
		noun = @nouns[noun_index]
		return '' if noun == nil || noun.get_property(:no_adjective)

		freq_counter = @dictionary.semantic_chooser(noun)
		adjective = @dictionary.get_random(Grammar::ADJECTIVE, &freq_counter)
		return '' unless adjective
		gram_case = parsed_opts[:case] || NOMINATIVE
		form = {:case=>gram_case, :gender=>noun.gender, :number=>noun.number, :animate => noun.animate}
		text = adjective.inflect(@grammar,form)

		if adjective.object_case
			object_text = handle_noun_object(adjective)
			text += ' ' + object_text unless object_text.empty?
		end
		text
	end

	def handle_verb(full_match,index,options)
		noun_index = self.class.read_index(full_match,index)
		@verbs_text[noun_index] ||= _handle_verb(full_match,noun_index,options)
	end

	def _handle_verb(full_match,noun_index,options)
		noun = nil
		parsed_opts = self.class.parse_verb_options(options)
		if parsed_opts[:form]
			form = parsed_opts[:form]
			@forced_subject_number = form[:number] if form[:number]
		else
			raise "no noun for #{full_match}" unless @nouns.include? noun_index
			noun = @nouns[noun_index]
			return '' unless noun
			form = {:number=>noun.number,:person=>noun.person}
		end

		freq_counter = if noun
			@dictionary.semantic_chooser(noun)
		elsif parsed_opts[:context_props]
			@dictionary.semantic_chooser(Word.new('', [], parsed_opts[:context_props]))
		else
			nil
		end

		verb = @dictionary.get_random(Grammar::VERB, &freq_counter)
		return '' unless verb
		@verbs[noun_index] = verb
		verb.inflect(@grammar,form)
	end

	def handle_object(full_match,index,options)
		noun_index = self.class.read_index(full_match,index)
		verb = @verbs[noun_index]
		raise "no verb for #{full_match}" unless verb
		if verb.object_case
			handle_noun_object(verb,noun_index)
		elsif verb.infinitive_object
			handle_infinitive_object(verb)
		elsif verb.adjective_object
			handle_adjective_object(verb,noun_index)
		else
			''
		end
	end

	# word - either adjective or verb
	# noun_index - index for noun to be set, may be nil, nothing will be set then
	def handle_noun_object(word,noun_index=nil)
		object = nil
		4.times do
			freq_counter = @dictionary.semantic_chooser(word)
			object = @dictionary.get_random_object(&freq_counter)
			next if (@subject && object.text == @subject.text)
			@nouns[noun_index] = object
			break
		end
		return '' unless object

		form = {:case=>word.object_case}
		inflected_object = object.inflect(@grammar,form)
		word.preposition ?
			@grammar.join_preposition_object(word.preposition,inflected_object) :
			inflected_object
	end

	def handle_infinitive_object(verb)
		object_verb = nil
		4.times do
			semantic_counter = @dictionary.semantic_chooser(verb)
			freq_counter = lambda do |freq,word|
				verb.text == word.text ? 0 : semantic_counter.call(freq,word)
			end
			object_verb = @dictionary.get_random(Grammar::VERB, &freq_counter)
			next if (verb.text == object_verb.text)
			break
		end
		return '' unless object_verb

		object_verb.inflect(@grammar,{:infinitive=>1})
	end

	def handle_adjective_object(verb,noun_index)
		noun = @nouns[noun_index]
		if noun
			gender = noun.gender
			number = noun.number
		else
			gender = MASCULINE
			number = @forced_subject_number || SINGULAR
		end

		freq_counter = @dictionary.semantic_chooser(verb)
		adjective = @dictionary.get_random(Dictionary::ADJECTIVE, &freq_counter)
		return '' unless adjective

		form = {:case=>NOMINATIVE, :gender=>gender, :number=>number}
		adjective.inflect(@grammar,form)
	end

	def handle_other(full_match,index,options)
		draw = rand
		return '' if draw >= @other_word_chance

		other_word = @dictionary.get_random(Grammar::OTHER)
		other_word ? other_word.text : ''
	end

	def handle_adverb(full_match,index,options)
		adverb = @dictionary.get_random(Grammar::ADVERB)
		adverb ? adverb.text : ''
	end

	def Sentence.read_index(full_match,index_match)
		index_match.strip! if index_match
		if index_match && !index_match.empty?
			raise "invalid index in #{full_match}, should be number" if index_match !~ /^\d+$/
			return index_match.to_i
		else
			return 1
		end
	end

	# matches tokens for given speech part, for example for NOUN matches
	# ${NOUN}, ${NOUN2} and ${NOUN(7)}
	# returns: [full_match, number, options_without_braces]
	# for example, for ${NOUN2(7)} returns ['${NOUN2(7)}', '2', '7']
	# for ${NOUN} returns ['${NOUN}','','']
	def Sentence.match_token(part)
		/(\$\{#{part}(\d*)(?:(?:\(([^)]*)\))?) *\})/
	end

	def match_token(part)
		Sentence.match_token(part)
	end

	# given block will receive single unparsed opt and parsed opts hash
	def self.option_parsing(opts, &block)
		parsed = {}
		context_props = {}
		semantic_opts = {'SEMANTIC'=>:semantic, 'NOT_WITH'=>:not_with, 'ONLY_WITH'=>:only_with,
			'TAKES_NO'=>:takes_no, 'TAKES_ONLY'=>:takes_only}
		if opts && !opts.empty?
			opts.split(/, */).each do |opt|
				catch :next_opt do
					semantic_opts.each do |string,name|
						if opt =~ /#{string} +(.+)/
							context_props[name] ||= []
							context_props[name] << $1
							throw :next_opt
						end
					end

					block.call(opt, parsed)
				end
			end
		end
		parsed[:context_props] = context_props unless context_props.empty?
		parsed
	end

	# parses verb options and returns a hash with parsed elements
	# hash keys: :form => hash with verb form
	def self.parse_verb_options(opts)
		self.option_parsing(opts) do |opt, parsed|
			if opt == 'INF'
				parsed[:form] = {:infinitive => 1}
			else
				form_i = Integer(opt)
				raise "nonsense form: #{form_i}" if form_i <= 0
				number_i,person = form_i.divmod(10)
				raise "unsupported number: #{number_i}" if number_i > 1
				raise "unsupported person: #{person}" if !([1,2,3].include?(person))
				form = {:person => person}
				form[:number] = (number_i == 1) ? PLURAL : SINGULAR
				parsed[:form] = form
			end
		end
	end

	def self.parse_adjective_options(opts)
		self.option_parsing(opts) do |opt, parsed|
			gram_case = Integer(opt)
			raise "invalid case: #{gram_case}" unless CASES.include?(gram_case)
			parsed[:case]=gram_case
		end
	end

	def self.parse_common_noun_options(opts)
		result = self.option_parsing(opts) do |opt, parsed|
			case opt
				when /^\d+$/ then
					parsed[:case] = Integer(opt)
					raise "invalid case: #{parsed[:case]}" unless CASES.include?(parsed[:case])
				when 'NE' then parsed[:not_empty] = true
				when 'EMPTY' then parsed[:empty] = true
				when 'IG_ONLY' then parsed[:ignore_only] = true
				else puts "warn: unknown noun option #{opt}"
			end
		end
		if result[:not_empty] && result[:empty]
			puts "warn: nonsense combination: NE and EMPTY"
		end
		result
	end
end

