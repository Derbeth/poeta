# -*- encoding: utf-8 -*-

require './grammar'
require './dictionary'
require './randomized_choice'
require './parser'

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
	attr_reader :text, :subject, :pattern
	attr_reader :debug_text

	def initialize(dictionary,grammar,conf,pattern)
		@dictionary,@grammar,@conf,@pattern = dictionary,grammar,conf,pattern.strip
		@logger = @conf.logger
		@parser = Poeta::Parser.new(Poeta::Parser::COMMA)

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
	end

	def validate
		# check that after replacing all placeholders there are no unclosed
		# placeholders left
		reduced_text = @pattern.clone
		Sentences::PARTS.each { |p| reduced_text.gsub!(match_token(p), '') }
		if reduced_text =~ /\$\{\S+/
			raise SentenceError, "syntax error near '#{$&}' - cannot handle this placeholder"
		end

		noun_occurs = {}
		[Sentences::SUBJECT, Sentences::NOUN].each do |part|
			@pattern.scan(match_token(part)) do
				full_match,noun_index,norm_index,options = process_match($&, $1)
				CommonNounOptionsParser.new(@dictionary,@logger).parse(options, full_match)
				noun_occurs[noun_index] ||= 0
				noun_occurs[noun_index] += 1
			end
		end
		[Sentences::VERB, Sentences::ADJECTIVE, Sentences::OBJECT].each do |part|
			@pattern.scan(match_token(part)) do
				full_match,noun_index,norm_index,options = process_match($&, $1)
				case part
					when Sentences::VERB
						parsed = VerbOptionsParser.new(@dictionary,@logger).parse(options, full_match)
						if parsed[:form]
							noun_occurs[noun_index] ||= 0
							noun_occurs[noun_index] += 1
							next
						end
					when Sentence::ADJECTIVE
						AdjectiveOptionsParser.new(@dictionary,@logger).parse(options, full_match)
				end
				raise SentenceError, "undefined noun referenced from #{full_match} in '#{pattern}'" unless noun_occurs.include? noun_index
			end
		end
	end

	# creates and returns a new sentence
	def write
		@text = @pattern.clone
		@text.gsub!(match_token(Sentences::OTHER))     { handle_other(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::SUBJECT))   { handle_subject(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::NOUN))      { handle_noun(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::ADJECTIVE)) { handle_adjective(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::VERB))      { handle_verb(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::OBJECT))    { handle_object(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::ADVERB))    { handle_adverb(*process_match($&, $1)) }
		@debug_text = "#{@pattern} #{@implicit_subject ? '(impl subj)' : ''}"
		@text.strip!
		@text.gsub!(/ {2,}/, ' ')
		@text.gsub!(/ +([.?!,])/, '\1')
		@text
	rescue
		raise raise $!, "error writing '#{@pattern}': #{$!}", $!.backtrace
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

	def handle_subject(full_match,subject_index,norm_index,options)
		parsed_opts = CommonNounOptionsParser.new(@dictionary,@logger).parse(options, full_match)
		if subject_index == 1 && @subject && !(@implicit_subject && parsed_opts[:no_implicit])
			noun = @subject
		else
			noun = get_random_subject(parsed_opts)
			@indexed_nouns[subject_index] = noun
		end
		@subject = noun if subject_index == 1
		if @implicit_subject && parsed_opts[:no_implicit]
			@implicit_subject = false
		end
		return '' if subject_index == 1 && @subject && @implicit_subject && !parsed_opts[:not_empty]
		return '' unless noun
		gram_case = parsed_opts[:case] || NOMINATIVE
		form = {:case=>gram_case}
		_common_handle_noun(noun,form)
	end

	def handle_noun(full_match,noun_index,norm_index,options)
		parsed_opts = CommonNounOptionsParser.new(@dictionary,@logger).parse(options, full_match)

		noun = get_random_standalone_noun(parsed_opts)

		@indexed_nouns[noun_index] = noun
		return '' unless noun
		gram_case = parsed_opts[:case] || NOMINATIVE
		form = {:case=>gram_case}
		_common_handle_noun(noun,form)
	end

	def handle_adjective(full_match,noun_index,norm_index,options)
		parsed_opts = AdjectiveOptionsParser.new(@dictionary,@logger).parse(options, full_match)
		raise "no noun for #{full_match}" unless @indexed_nouns.include? noun_index

		if noun_index == 1 && @subject && @implicit_subject
			return ''  if !@conf.implicit_subj_adj || !check_chance(@conf.object_adj_chance)
		end

		noun = @indexed_nouns[noun_index]
		return '' if noun == nil

		_handle_adjective(noun, parsed_opts)
	end

	# handled adj_opts: :case, :number
	def _handle_adjective(noun, adj_opts={}, exclude_double=false)
		return '' if noun.get_property(:no_adjective)
		semantic_counter = @dictionary.semantic_chooser(noun)
		adjective = @dictionary.get_random_adjective(noun, exclude_double, &semantic_counter)
		unless adjective
			@conf.logger.debug "Cannot find adjective matching #{noun} (#{noun.get_properties})"
			return ''
		end

		@adjectives << adjective
		gram_case = adj_opts[:case] || NOMINATIVE
		number = adj_opts[:number] || noun.number
		form = {:case=>gram_case, :gender=>noun.gender, :number=>number, :animate => noun.animate}
		inflected = _common_handle_word_with_attributes(adjective, form)

		if adjective.double && check_chance(@conf.double_adj_chance)
			inflected += ' ' + _handle_adjective(noun, adj_opts, true)
		end

		inflected
	end

	# takes a noun and grammar form, returns inflected noun, possibly with preposition and attribute
	def _common_handle_noun(noun, form,allow_recur=MAX_ATTR_RECUR)
		# remember the noun to prevent the same noun appearing twice in a sentence
		@nouns << noun

		inflected = _common_handle_word_with_attributes(noun, form, allow_recur)

		if allow_recur > 0 && !inflected.empty? && check_chance(@conf.double_noun_chance)
			attribute = handle_noun_object(noun, NounObject.new(GENITIVE), DBL_NOUN_RECUR)
			inflected = @grammar.join_attribute_noun(inflected, attribute) unless attribute.empty?
			@conf.logger.debug "Noun noun: #{noun} #{attribute} -> #{inflected}"
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

	def handle_verb(full_match,noun_index,norm_index,options)
		@verbs_text[norm_index] ||= _handle_verb(full_match,noun_index,norm_index,options)
	end

	def _handle_verb(full_match,noun_index,norm_index,options)
		noun = nil
		parsed_opts = VerbOptionsParser.new(@dictionary,@logger).parse(options, full_match)
		if parsed_opts[:form]
			form = parsed_opts[:form]
			@forced_subject_number = form[:number] if form[:number]
		else
			raise "no noun for #{full_match}" unless @indexed_nouns.include? noun_index
			noun = @indexed_nouns[noun_index]
			return '' unless noun
			form = {:number=>noun.number,:person=>noun.person}
		end

		verb = get_random_verb_as_predicate(noun, parsed_opts)
		return '' unless verb
		@verbs[norm_index] = verb
		verb.inflect(@grammar,form)
	end

	def handle_object(full_match,noun_index,norm_index,options)
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
		unless object
			@conf.logger.debug "Could not find matching object for #{word} with #{object_spec}"
			return ''
		end

		# resolve adjective before inflecting object
		# in order to avoid assigning first object adjective to the
		# noun attribute added to the object
		adj_text = nil
		adj_chance = @adjectives.empty?  ? @conf.object_adj_chance : @conf.object_adj_chance/2
		if check_chance(adj_chance)
			adj_text = _handle_adjective(object, {:case=>object_spec.case})
		end

		form = {:case=>object_spec.case}
		form[:preposition] = object_spec.preposition if object_spec.preposition
		inflected_object = _common_handle_noun(object, form, allow_recur-1) # -1 to prevent infinite loop danger?

		inflected_object = adj_text + ' ' + inflected_object if adj_text && !adj_text.empty?

		object_spec.preposition ?
			@grammar.join_preposition_object(object_spec.preposition,inflected_object) :
			inflected_object
	end

	# returns true if it is forbidden to use the second noun as the attribute
	# for the first noun
	def noun_noun_forbidden?(main_noun, attribute_noun)
		return true if main_noun.get_property(:no_attribute)
		[main_noun, attribute_noun].each do |noun|
			return true if noun.person != 3 || noun.get_property(:no_noun_noun)
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
			next if (object_verb.nil? || verb.text == object_verb.text)
			break
		end
		unless object_verb
			@conf.logger.warn "Could not find matching object for #{verb} with #{object_spec}"
			return ''
		end

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
		unless adjective
			@conf.logger.warn "Could not find matching adjective object for #{verb} (#{verb.get_properties})"
			return ''
		end

		form = {:case=>NOMINATIVE, :gender=>gender, :number=>number}
		adjective.inflect(@grammar,form)
	end

	def handle_other(full_match,noun_index,norm_index,options)
		return '' unless check_chance(@conf.other_word_chance)

		other_word = @dictionary.get_random(Grammar::OTHER)
		other_word ? other_word.text : ''
	end

	def handle_adverb(full_match,noun_index,norm_index,options)
		noun = @indexed_nouns[noun_index]
		freq_counter = noun ? @dictionary.semantic_chooser(noun) : nil
		adverb = @dictionary.get_random(Grammar::ADVERB, &freq_counter)
		adverb ? adverb.text : ''
	end

	def get_random_subject(parsed_opts)
		semantic_chooser = parsed_opts[:context_props] ?
			@dictionary.semantic_chooser(FakeWordWithSemantic.new parsed_opts[:context_props]) :
			nil

		@dictionary.get_random_subject do |counted_frequency,word|
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
	end

	def get_random_standalone_noun(parsed_opts)
		semantic_chooser = parsed_opts[:context_props] ?
			@dictionary.semantic_chooser(FakeWordWithSemantic.new parsed_opts[:context_props]) :
			nil

		@dictionary.get_random(Grammar::NOUN) do |frequency, word|
			if word.text.empty?
				0
			elsif semantic_chooser
				semantic_chooser.call(frequency,word)
			else
				frequency
			end
		end
	end

	def get_random_verb_as_predicate(noun, parsed_opts)
		semantic_chooser = if noun || parsed_opts[:context_props]
			@dictionary.semantic_chooser(merge_with_semantic_opts(noun, parsed_opts[:context_props]))
		else
			nil
		end

		@dictionary.get_random_verb_as_predicate do |freq,word|
			semantic_chooser ? semantic_chooser.call(freq,word) : freq
		end
	end

	def merge_with_semantic_opts(word, context_opts)
		merged_opts = {}
		SEMANTIC_OPTS.values.each do |opt|
			word_vals = word ? word.get_property(opt) : nil
			context_vals = context_opts ? context_opts[opt] : nil
			merged_opts[opt] = (word_vals || []) + (context_vals || []) if word_vals || context_vals
		end
		FakeWordWithSemantic.new(merged_opts, word ? word.text : nil)
	end

	# matches tokens for given speech part, for example for NOUN matches
	# ${NOUN}, ${NOUN2} and ${NOUN(7)}
	def match_token(part)
		/\$\{#{part}([^{}]*)\}/
	end

	def process_match(full_match, match)
		to_parse = match ? match.dup : ''
		subj_index, normalized_full_index, options = 1, '1', nil
		case to_parse
			when /^(\d+)\.(\d+)/ then subj_index, normalized_full_index = $1.to_i, $&
			when /^\d+/ then subj_index, normalized_full_index = $&.to_i, $&
		end
		to_parse.sub!(/^(\d+\.\d+|\d+)/, '')
		to_parse.strip!
		if to_parse =~ /^\((.+)\)$/
			options = @parser.parse($1)
		elsif to_parse =~ /\S/
			puts "warn: invalid syntax of '#{full_match}'"
		end
		options ||= Poeta::ParseResult.new
		[full_match, subj_index, normalized_full_index, options]
	end

	class SentencePartParser
		def initialize(dictionary,logger)
			@dictionary, @logger = dictionary, logger
		end

		def parse(opts, full_match)
			@parsed = {}
			@context_props = {}
			opts.each_option do |name, params|
				handle_option(name, params)
			end
			validate
			@parsed
		rescue RuntimeError
			puts "warn: #{full_match} - #{$!}"
			@parsed
		end

		protected
		attr_reader :parsed

		def handle_option(name, params)
			@logger.warn "warn: unknown option #{name}"
		end

		def validate
		end
	end

	class SemanticEnabledSentencePartParser < SentencePartParser
		def initialize(dictionary,logger)
			super(dictionary,logger)
		end

		protected

		def validate
			super
			unless @context_props.empty?
				self.parsed[:context_props] = @context_props
				err_msg = @dictionary.validate_word(FakeWordWithSemantic.new @context_props)
				raise err_msg if err_msg
			end
		end

		def handle_option(name, params)
			if SEMANTIC_OPTS.include? name
				@context_props ||= {}
				@context_props[SEMANTIC_OPTS[name]] = params
			else
				super(name, params)
			end
		end
	end

	class VerbOptionsParser < SemanticEnabledSentencePartParser
		def initialize(dictionary,logger)
			super(dictionary,logger)
		end

		protected

		def handle_option(name, params)
			case name
				when 'INF' then parsed[:form] = {:infinitive => true}
				when 'IMP' then
					parsed[:form] ||= {}
					parsed[:form][:imperative] = true
				when /^\d+$/
					form_i = Integer(name)
					raise "nonsense form: #{form_i}" if form_i <= 0
					number_i,person = form_i.divmod(10)
					raise "unsupported number: #{number_i}" if number_i > 1
					raise "unsupported person: #{person}" if !(PERSONS.include?(person))
					parsed[:form] ||= {}
					number = (number_i == 1) ? PLURAL : SINGULAR
					parsed[:form].merge!({:person=>person, :number=>number})
				else
					super(name, params)
			end
		end
	end

	class AdjectiveOptionsParser < SentencePartParser
		def initialize(dictionary,logger)
			super(dictionary,logger)
		end

		protected

		def handle_option(name, params)
			number_i,gram_case = Integer(name).divmod(10)
			raise "invalid case: #{gram_case}" unless CASES.include?(gram_case)
			parsed[:case]=gram_case
			parsed[:number] = (number_i == 1) ? PLURAL : SINGULAR
		end
	end

	class CommonNounOptionsParser < SemanticEnabledSentencePartParser
		def initialize(dictionary,logger)
			super(dictionary,logger)
		end

		protected

		def handle_option(name, params)
			case name
				when /^\d+$/ then
					parsed[:case] = Integer(name)
					raise "invalid case: #{parsed[:case]}" unless CASES.include?(parsed[:case])
				when 'NE' then parsed[:not_empty] = true
				when 'EMPTY' then parsed[:empty] = true
				when 'IG_ONLY' then parsed[:ignore_only] = true
				when 'NO_IMPL' then parsed[:no_implicit] = true
				else
					super(name, params)
			end
		end

		def validate
			super
			if parsed[:not_empty] && parsed[:empty]
				raise "nonsense combination: NE and EMPTY"
			end
		end
	end

	class FakeWordWithSemantic < Grammar::Word
		def initialize(opts, text='')
			super(text, [], opts)
		end
	end
end
