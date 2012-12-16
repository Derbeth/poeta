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

	PARTS = [SUBJECT, NOUN, ADJECTIVE, VERB, OBJECT, ADVERB, OTHER]
end

class SentenceError < RuntimeError
end

class Sentence
	attr_reader :double_adj_chance, :double_noun_chance, :other_word_chance, :object_adj_chance
	attr_reader :text, :subject, :pattern
	attr_reader :debug_text

	def initialize(dictionary,grammar,conf,pattern)
		@dictionary,@grammar,@conf,@pattern = dictionary,grammar,conf,pattern.strip
		@logger = @conf.logger
		
		@subject = nil
		@implicit_subject = false
		@forced_subject_number = nil
		# maps: verb_index => word object; @indexed_nouns include only $SUBJ/$NOUN and *not* $OBJ
		@indexed_nouns,@verbs = {},{}
		# maps full indices to resolved verbs text like {'1' => 'goes', '1.2' => 'runs'}
		@verbs_text = {}
		# set of all nouns used in a sentence, including also objects (contrary to @indexed_nouns)
		@nouns = []
		@adjectives = []
		self.other_word_chance = DEFAULT_OTHER_CHANCE
		self.double_adj_chance = DEFAULT_DBL_ADJ_CHANCE
		self.double_noun_chance = DEFAULT_DBL_NOUN_CHANCE
		self.object_adj_chance = DEFAULT_OBJ_ADJ_CHANCE
	end

	def other_word_chance=(chance)
		validate_chance(chance)
		@other_word_chance = chance
	end

	def double_adj_chance=(chance)
		validate_chance(chance)
		@double_adj_chance = chance
	end

	def double_noun_chance=(chance)
		validate_chance(chance)
		@double_noun_chance = chance
	end

	def object_adj_chance=(chance)
		validate_chance(chance)
		@object_adj_chance = chance
	end

	def validate_chance(chance)
		raise ArgumentError, "chance should be 0.0 and 1.0, but got #{chance}" if chance < 0.0 || chance > 1.0
	end

	def Sentence.validate_pattern(pattern)
		# check that after replacing all placeholders there are no unclosed
		# placeholders left
		reduced_text = pattern.clone
		Sentences::PARTS.each { |p| reduced_text.gsub!(match_token(p), '') }
		if reduced_text =~ /\$\{\S+/
			raise SentenceError, "syntax error near '#{$&}' - cannot handle this placeholder"
		end

		noun_occurs = {}
		[Sentences::SUBJECT, Sentences::NOUN].each do |part|
			pattern.scan(match_token(part)) do |full_match,index,options|
				noun_index, norm_index = read_index(full_match,index)
				noun_occurs[noun_index] ||= 0
				noun_occurs[noun_index] += 1
			end
		end
		[Sentences::VERB, Sentences::ADJECTIVE, Sentences::OBJECT].each do |part|
			pattern.scan(match_token(part)) do |full_match,index,options|
				noun_index, norm_index = read_index(full_match,index)
				if part == Sentences::VERB
					parsed = parse_verb_options(options)
					if parsed[:form]
						noun_occurs[noun_index] ||= 0
						noun_occurs[noun_index] += 1
						next
					end
				end
				raise SentenceError, "undefined noun referenced from #{full_match} in '#{pattern}'" unless noun_occurs.include? noun_index
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
		@debug_text = "#{@pattern} #{@implicit_subject ? '(impl subj)' : ''}"
		@text.strip!
		@text.gsub!(/ {2,}/, ' ')
		@text.gsub!(/ +([.?!,])/, '\1')
		@text
	end

	# Forces the sentence to use the given noun as the first subject.
	# The following subjects (if present) are chosen freely.
	def subject=(s)
		@subject = s
		@indexed_nouns[1] = @subject
	end

	# Forces the sentence to use the given noun as the first subject, but without writing the noun
	# text
	def implicit_subject=(s)
		self.subject = s
		@implicit_subject = true
	end

	private
	
	include ChanceChecker

	MAX_ATTR_RECUR = 3
	DBL_NOUN_RECUR = 1
	DEFAULT_OTHER_CHANCE = 0.3
	DEFAULT_DBL_ADJ_CHANCE = 0.3
	DEFAULT_DBL_NOUN_CHANCE = 0.2
	DEFAULT_OBJ_ADJ_CHANCE = 0.3

	def handle_subject(full_match,index,options)
		subject_index, norm_index = self.class.read_index(full_match,index)
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

				semantic_chooser ? semantic_chooser.call(new_frequency,word) : new_frequency
			end
			@indexed_nouns[subject_index] = noun
		end
		@subject ||= noun
		return '' if subject_index == 1 && @subject && @implicit_subject && !parsed_opts[:not_empty]
		return '' unless noun
		gram_case = parsed_opts[:case] || NOMINATIVE
		form = {:case=>gram_case}
		_common_handle_noun(noun,form)
	end

	def handle_noun(full_match,index,options)
		noun_index, norm_index = self.class.read_index(full_match,index)
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

		@indexed_nouns[noun_index] = noun
		return '' unless noun
		gram_case = parsed_opts[:case] || NOMINATIVE
		form = {:case=>gram_case}
		_common_handle_noun(noun,form)
	end

	def handle_adjective(full_match,index,options)
		noun_index, norm_index = self.class.read_index(full_match,index)
		parsed_opts = self.class.parse_adjective_options(options)
		raise "no noun for #{full_match}" unless @indexed_nouns.include? noun_index
		noun = @indexed_nouns[noun_index]
		return '' if noun == nil || noun.get_property(:no_adjective)
		return '' if noun_index == 1 && @subject && @implicit_subject && !check_chance(object_adj_chance)

		_handle_adjective(noun, parsed_opts)
	end

	# handled adj_opts: :case, :number
	def _handle_adjective(noun, adj_opts={}, exclude_double=false)
		semantic_counter = @dictionary.semantic_chooser(noun)
		if exclude_double
			freq_counter = lambda do |freq,candidate|
				candidate.double ? 0 : semantic_counter.call(freq,candidate)
			end
		else
			freq_counter = semantic_counter
		end
		adjective = @dictionary.get_random(Grammar::ADJECTIVE, &freq_counter)
		return '' unless adjective

		@adjectives << adjective
		gram_case = adj_opts[:case] || NOMINATIVE
		number = adj_opts[:number] || noun.number
		form = {:case=>gram_case, :gender=>noun.gender, :number=>number, :animate => noun.animate}
		inflected = _common_handle_word_with_attributes(adjective, form)

		if adjective.double && check_chance(double_adj_chance)
			inflected += ' ' + _handle_adjective(noun, adj_opts, true)
		end

		inflected
	end

	# takes a noun and grammar form, returns inflected noun, possibly with preposition and attribute
	def _common_handle_noun(noun, form,allow_recur=MAX_ATTR_RECUR)
		# remember the noun to prevent the same noun appearing twice in a sentence
		@nouns << noun

		inflected = _common_handle_word_with_attributes(noun, form, allow_recur)

		if allow_recur > 0 && !inflected.empty? && check_chance(double_noun_chance)
			attribute = handle_noun_object(noun, NounObject.new(GENITIVE), DBL_NOUN_RECUR)
			inflected = @grammar.join_attribute_noun(inflected, attribute) unless attribute.empty?
		end

		inflected
	end

	# takes a word possibly having an attribute (so a noun or adjective),
	# returns inflected word, possibly linked with a preposition and attribute
	def _common_handle_word_with_attributes(word, form,allow_recur=MAX_ATTR_RECUR)
		inflected = word.inflect(@grammar,form)

		if allow_recur > 0 && !word.attributes.empty?
			attribute_text = handle_noun_object(word, word.attributes[0],allow_recur)
			inflected += ' ' + attribute_text unless attribute_text.empty?
		end

		inflected
	end

	def handle_verb(full_match,index,options)
		noun_index, norm_index = self.class.read_index(full_match,index)
		@verbs_text[norm_index] ||= _handle_verb(full_match,noun_index,norm_index,options)
	end

	def _handle_verb(full_match,noun_index,norm_index,options)
		noun = nil
		parsed_opts = self.class.parse_verb_options(options)
		if parsed_opts[:form]
			form = parsed_opts[:form]
			@forced_subject_number = form[:number] if form[:number]
		else
			raise "no noun for #{full_match}" unless @indexed_nouns.include? noun_index
			noun = @indexed_nouns[noun_index]
			return '' unless noun
			form = {:number=>noun.number,:person=>noun.person}
		end

		semantic_chooser = if noun
			@dictionary.semantic_chooser(noun)
		elsif parsed_opts[:context_props]
			@dictionary.semantic_chooser(Word.new('', [], parsed_opts[:context_props]))
		else
			nil
		end

		verb = @dictionary.get_random_verb_as_predicate do |freq,word|
			if parsed_opts[:only] && word.text != parsed_opts[:only]
				freq = 0
			end
			semantic_chooser ? semantic_chooser.call(freq,word) : freq
		end
		return '' unless verb
		@verbs[norm_index] = verb
		verb.inflect(@grammar,form)
	end

	def handle_object(full_match,index,options)
		noun_index, norm_index = self.class.read_index(full_match,index)
		verb = @verbs[norm_index]
		raise "no verb for #{full_match}" unless verb
		_handle_object(verb, noun_index)
	end

	# noun_index - index of the subject connected with the verb, needed to properly handle form of adjective object
	def _handle_object(verb, noun_index)
		resolved_objects = verb.objects.map do |o|
			if o.is_noun?
				handle_noun_object(verb,o)
			elsif o.is_infinitive?
				handle_infinitive_object(verb,o,noun_index)
			elsif o.is_adjective?
				handle_adjective_object(verb,noun_index)
			else
				puts "warn: verb #{verb} contains object #{o} which is impossible to handle"
				''
			end
		end

		resolved_objects.join(' ')
	end

	# word - adjective, noun or verb needing an object
	# object_spec - specification of how to find object, of class GramObject
	def handle_noun_object(word, object_spec,allow_recur=MAX_ATTR_RECUR)
		object = nil
		12.times do
			semantic_counter = @dictionary.semantic_chooser(word)
			freq_counter = lambda do |freq,candidate_word|
				if word.text == candidate_word.text
					0
				elsif word.class == Noun && noun_noun_forbidden?(word, candidate_word)
					0
				else
					semantic_counter.call(freq,candidate_word)
				end
			end
			object = @dictionary.get_random_object(&freq_counter)
			next if (object && @nouns.find { |n| n.text == object.text})
			break
		end
		return '' unless object

		# resolve adjective before inflecting object
		# in order to avoid assigning first object adjective to the
		# noun attribute added to the object
		adj_text = nil
		adj_chance = @adjectives.empty?  ? object_adj_chance : object_adj_chance/2
		if check_chance(adj_chance)
			adj_text = _handle_adjective(object, {:case=>object_spec.case})
		end

		form = {:case=>object_spec.case}
		inflected_object = _common_handle_noun(object, form, allow_recur-1) # -1 to prevent infinite loop danger?

		inflected_object = adj_text + ' ' + inflected_object if adj_text && !adj_text.empty?

		object_spec.preposition ?
			@grammar.join_preposition_object(object_spec.preposition,inflected_object) :
			inflected_object
	end

	# returns true if it is forbidden to use the second noun as the attribute
	# for the first noun
	def noun_noun_forbidden?(main_noun, attribute_noun)
		[main_noun, attribute_noun].each do |noun|
			return true if noun.person != 3
		end
		false
	end

	def handle_infinitive_object(verb, object_spec, noun_index)
		object_verb = nil
		4.times do
			semantic_counter = @dictionary.semantic_chooser(verb)
			freq_counter = lambda do |freq,word|
				verb.text == word.text ? 0 : semantic_counter.call(freq,word)
			end
			object_verb = @dictionary.get_random_verb_as_object(&freq_counter)
			next if (verb.text == object_verb.text)
			break
		end
		return '' unless object_verb

		text = object_verb.inflect(@grammar,{:infinitive=>1})
		if !object_verb.objects.empty?
			text += ' ' + _handle_object(object_verb, noun_index)
		end
		if object_spec.preposition
			text = object_spec.preposition + ' ' + text
		end
		text
	end

	def handle_adjective_object(verb,noun_index)
		noun = @indexed_nouns[noun_index]
		if noun
			gender = noun.gender
			number = noun.number
		else
			gender = MASCULINE
			number = @forced_subject_number || SINGULAR
		end

		freq_counter = @dictionary.semantic_chooser(verb)
		adjective = @dictionary.get_random_adjective_object(&freq_counter)
		return '' unless adjective

		form = {:case=>NOMINATIVE, :gender=>gender, :number=>number}
		adjective.inflect(@grammar,form)
	end

	def handle_other(full_match,index,options)
		return '' unless check_chance(@other_word_chance)

		other_word = @dictionary.get_random(Grammar::OTHER)
		other_word ? other_word.text : ''
	end

	def handle_adverb(full_match,index,options)
		noun_index, norm_index = self.class.read_index(full_match,index)
		noun = @indexed_nouns[noun_index]
		freq_counter = noun ? @dictionary.semantic_chooser(noun) : nil
		adverb = @dictionary.get_random(Grammar::ADVERB, &freq_counter)
		adverb ? adverb.text : ''
	end

	# full_match - like ${NOUN} or ${VERB2} or ${VERB5.1}
	# index_match - number matched from full_match, like '', '2', '5.1'
	# returns pair: [subject_index,normalized_index_match]
	# here: [1, '1'], [2, '2'] and [5, '5.1']
	def Sentence.read_index(full_match,index_match)
		dot_part = nil
		if index_match
			index_match.strip!
			if index_match =~ /\..*/
				index_match,dot_part = $`, $&;
			end
		end

		int_index = nil
		if index_match && !index_match.empty?
			raise "invalid index in #{full_match}, should be number" if index_match !~ /^\d+$/
			int_index = index_match.to_i
		else
			int_index = 1
		end

		[int_index, "#{int_index}#{dot_part}"]
	end

	# matches tokens for given speech part, for example for NOUN matches
	# ${NOUN}, ${NOUN2} and ${NOUN(7)}
	# returns: [full_match, number, options_without_braces]
	# for example, for ${NOUN2(7)} returns ['${NOUN2(7)}', '2', '7']
	# for ${NOUN2.1} return ['${NOUN2.1}', '2.1', '']
	# for ${NOUN} returns ['${NOUN}','','']
	def Sentence.match_token(part)
		/(\$\{#{part}(\d+\.\d+|\d*)(?:(?:\(([^)]*)\))?) *\})/
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
						if opt =~ /^#{string} +(.+)/
							context_props[name] ||= []
							context_props[name] << $1
							throw :next_opt
						end
					end
					if opt =~ /^ONLY +(\S+)/
						parsed[:only] = $1
						throw :next_opt
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
			case opt
				when 'INF' then parsed[:form] = {:infinitive => true}
				when 'IMP' then
					parsed[:form] ||= {}
					parsed[:form][:imperative] = true
				else
					form_i = Integer(opt)
					raise "nonsense form: #{form_i}" if form_i <= 0
					number_i,person = form_i.divmod(10)
					raise "unsupported number: #{number_i}" if number_i > 1
					raise "unsupported person: #{person}" if !(PERSONS.include?(person))
					parsed[:form] ||= {}
					number = (number_i == 1) ? PLURAL : SINGULAR
					parsed[:form].merge!({:person=>person, :number=>number})
			end
		end
	end

	def self.parse_adjective_options(opts)
		self.option_parsing(opts) do |opt, parsed|
			number_i,gram_case = Integer(opt).divmod(10)
			raise "invalid case: #{gram_case}" unless CASES.include?(gram_case)
			parsed[:case]=gram_case
			parsed[:number] = (number_i == 1) ? PLURAL : SINGULAR
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

