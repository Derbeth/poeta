# -*- encoding: utf-8 -*-

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

class BaseSentence
	attr_reader :text, :subject, :pattern
	attr_reader :debug_text

	def initialize(dictionary,grammar,conf,pattern)
		@dictionary,@grammar,@conf,@pattern = dictionary,grammar,conf,pattern.strip
		@logger = @conf.logger

		@parser = Poeta::Parser.new(Poeta::Parser::COMMA)

		@subject = nil
		@implicit_subject = false
	end

	# creates and returns a new sentence
	def write
		@text = @pattern.clone
		@text.gsub!(match_token(Sentences::OTHER))     { handle_other(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::SUBJECT))   { parse_handle_subject(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::NOUN))      { parse_handle_noun(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::ADJECTIVE)) { parse_handle_adjective(*process_match($&, $1)) }
		@text.gsub!(match_token(Sentences::VERB))      { parse_handle_verb(*process_match($&, $1)) }
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
	end

	# Forces the sentence to use the given noun as the first subject, but without writing the noun
	# text
	def implicit_subject=(s)
		self.subject = s
		@implicit_subject = true
	end

	protected

	class FakeWordWithSemantic < Grammar::Word
		def initialize(opts, text='')
			super(text, [], opts)
		end
	end

	private

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

	def parse_handle_subject(full_match,subject_index,norm_index,options)
		parsed_opts = CommonNounOptionsParser.new(@dictionary,@logger).parse(options, full_match)
		handle_subject(full_match,subject_index,norm_index,parsed_opts)
	end

	def parse_handle_noun(full_match,noun_index,norm_index,options)
		parsed_opts = CommonNounOptionsParser.new(@dictionary,@logger).parse(options, full_match)
		handle_noun(full_match,noun_index,norm_index,parsed_opts)
	end

	def parse_handle_adjective(full_match,noun_index,norm_index,options)
		parsed_opts = AdjectiveOptionsParser.new(@dictionary,@logger).parse(options, full_match)
		handle_adjective(full_match,noun_index,norm_index,parsed_opts)
	end

	def parse_handle_verb(full_match,noun_index,norm_index,options)
		parsed_opts = VerbOptionsParser.new(@dictionary,@logger).parse(options, full_match)
		handle_verb(full_match,noun_index,norm_index,parsed_opts)
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
			parsed[:case] = gram_case
			parsed[:number] = PLURAL if number_i == 1
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

end
