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
	ADVERB = 'ADV'
	OTHER = 'OTHER'
end

class String
	def fixed_ljust(width)
		result = ljust(width)
		two_byte_chars_count = 0;
		scan(/[ąćęłóńśżź]/) { two_byte_chars_count += 1 }
		two_byte_chars_count /= 2
# 		puts "fuck: '#{self}' #{self.size}>#{result.size} #{two_byte_chars_count}"
# 		result
# 		result[0..(result.size-two_byte_chars_count)]
		result + ' ' * two_byte_chars_count
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
	attr_reader :text, :subject, :other_word_chance, :pattern

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
		pattern_copy = pattern.gsub(/\$\{[^{}]+\}/, '')

		noun_occurs = {}
		[Sentences::SUBJECT, Sentences::NOUN].each do |part|
			pattern.scan(match_token(part)) do |full_match,index,options|
				noun_index = read_index(full_match,index)
				noun_occurs[noun_index] ||= 0
				noun_occurs[noun_index] += 1
				raise "too many occurances of noun #{noun_index} in '#{pattern}'" if noun_occurs[noun_index] > 1
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
			noun = @dictionary.get_random_subject do |counted_frequency,word|
				if parsed_opts[:not_empty] && word.text.empty?
					0
				elsif parsed_opts[:ignore_only]
					word.frequency
				else
					counted_frequency
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

		noun = @dictionary.get_random(Grammar::NOUN) do |frequency, word|
			word.text.empty? ? 0 : frequency
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
		return '' if noun == nil || noun.person != 3

		freq_counter = @dictionary.semantic_chooser(noun)
		adjective = @dictionary.get_random(Grammar::ADJECTIVE, &freq_counter)
		return '' unless adjective
		gram_case = parsed_opts[:case] || NOMINATIVE
		form = {:case=>gram_case, :gender=>noun.gender, :number=>noun.number}
		adjective.inflect(@grammar,form,noun.animate)
	end

	def handle_verb(full_match,index,options)
		noun_index = self.class.read_index(full_match,index)
		parsed_opts = self.class.parse_verb_options(options)
		if parsed_opts[:form]
			form = parsed_opts[:form]
		else
			raise "no noun for #{full_match}" unless @nouns.include? noun_index
			noun = @nouns[noun_index]
			return '' unless noun
			form = {:number=>noun.number,:person=>noun.person}
		end
		verb = @dictionary.get_random(Grammar::VERB)
		return '' unless verb
		@verbs[noun_index] = verb
		verb.inflect(@grammar,form)
	end

	def handle_object(full_match,index,options)
		noun_index = self.class.read_index(full_match,index)
		verb = @verbs[noun_index]
		raise "no verb for #{full_match}" unless verb
		if verb.object_case
			handle_noun_object(noun_index,verb)
		elsif verb.infinitive_object
			handle_infinitive_object(verb)
		else
			''
		end
	end

	def handle_noun_object(noun_index,verb)
		object = nil
		4.times do
			freq_counter = @dictionary.semantic_chooser(verb)
			object = @dictionary.get_random_object(&freq_counter)
			next if (@subject && object.text == @subject.text)
			@nouns[noun_index] = object
			break
		end
		return '' unless object

		form = {:case=>verb.object_case}
		inflected_object = object.inflect(@grammar,form)
		verb.preposition ?
			join_preposition_object(verb.preposition,inflected_object) :
			inflected_object
	end

	def join_preposition_object(preposition,object)
		prep = preposition.clone
		consonants = %w{b c d f g h j k l ł m n p r s t w z}
		cons_match = "[#{consonants.join}]"
		case
			when prep == 'z' &&
				object =~ /^(z#{cons_match}|s[#{consonants-['z']}]|sz#{cons_match})/ then prep = 'ze'
			when prep == 'w' && object =~ /^w#{cons_match}/ then prep = 'we'
		end
		prep + ' ' + object
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
		if index_match && !index_match.empty?:
			raise "invalid index in #{full_match}, should be number" if index_match !~ /^\d+$/
			return index_match.to_i
		end
		return 1
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

	# parses verb options and returns a hash with parsed elements
	# hash keys: :form => hash with verb form
	def self.parse_verb_options(opts)
		parsed = {}
		if opts && !opts.empty?
			form_i = Integer(opts)
			raise "nonsense form: #{form_i}" if form_i <= 0
			number_i,person = form_i.divmod(10)
			raise "unsupported number: #{number_i}" if number_i > 1
			raise "unsupported person: #{person}" if !([1,2,3].include?(person))
			form = {:person => person}
			form[:number] = (number_i == 1) ? PLURAL : SINGULAR
			parsed[:form] = form
		end
		parsed
	end

	def self.parse_adjective_options(opts)
		parsed = {}
		if opts && !opts.empty?
			gram_case = Integer(opts)
			raise "invalid case: #{gram_case}" unless CASES.include?(gram_case)
			parsed[:case]=gram_case
		end
		parsed
	end

	def self.parse_common_noun_options(opts)
		parsed = {}
		if opts && !opts.empty?
			opts.split(/, */).each do |opt|
				case opt
					when /^\d+$/ then
						parsed[:case] = Integer(opt)
						raise "invalid case: #{parsed[:case]}" unless CASES.include?(parsed[:case])
					when 'NE' then parsed[:not_empty] = true
					when 'IG_ONLY' then parsed[:ignore_only] = true
					else puts "warn: unknown noun option #{opt}"
				end
			end
		end
		parsed
	end
end

