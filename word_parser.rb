# -*- encoding: utf-8 -*-

require './word'

module Grammar
	SEMANTIC_OPTS = {'SEMANTIC'=>:semantic,
		'ONLY_WITH'=>:only_with, 'NOT_WITH'=>:not_with,
		'ONLY_WITH_W'=>:only_with_word, 'NOT_WITH_W'=>:not_with_word,
		'TAKES_ONLY'=>:takes_only, 'TAKES_NO'=>:takes_no,
		'TAKES_ONLY_W'=>:takes_only_word, 'TAKES_NO_W'=>:takes_no_word}

	# exception to be thrown from parsers to the classes outside the module
	class ParseError < StandardError
	end

	class WordParser
		def parse(text,gram_props,frequency,line)
			raise 'unimplemented'
		end

		protected

		# global_props - hash where read options will be stored
		def handle_option(opt_name, opt_params, general_props)
			SEMANTIC_OPTS.each_pair do |name, store_key|
				if name == opt_name
					general_props[store_key] ||= []
					general_props[store_key] += opt_params
					return
				end
			end

			puts "warn: unknown option #{opt_name}"
		end

		def parse_noun_object(opt_name, opt_params)
			object_case, preposition = nil, nil
			case opt_params.size
				when 2
					preposition = opt_params[0]
					object_case = Integer(opt_params[1])
				when 1
					object_case = Integer(opt_params[0])
				else
					raise WordParserError, "wrong format for #{opt_name}"
			end
			NounObject.new(object_case, preposition)
		end

		# throws an exception if parsed option has any parameters
		def assert_no_params(opt_name, opt_params)
			raise WordParserError, "#{opt_name} takes no parameters" if opt_params != nil
		end

		# throws an exception if parsed option has number of parameters different than given
		def assert_params_count(count, opt_name, opt_params)
			raise WordParserError, "#{opt_name} expects #{count} params" if opt_params.nil? || opt_params.size != count
		end

		def new_parser
			Poeta::Parser.new
		end

		class WordParserError < RuntimeError
		end
	end

	class NounParser < WordParser
		def parse(text,gram_props,frequency,line)
			gender,number,person,animate,suffix = MASCULINE,SINGULAR,3,true,nil
			general_props = {}
			attributes = []

			new_parser.parse(line).each_option do |opt_name, opt_params|
				case opt_name
					when /^([mfn])$/
						assert_no_params(opt_name, opt_params)
						gender = STRING2GENDER[opt_name]
					when 'Pl'
						assert_no_params(opt_name, opt_params)
						number = PLURAL
					when 'nan'
						assert_no_params(opt_name, opt_params)
						animate = false
					when 'PERSON'
						assert_params_count(1, opt_name, opt_params)
						person = Integer(opt_params[0])
					when 'SUFFIX'
						assert_params_count(1, opt_name, opt_params)
						suffix = opt_params[0]
					when 'NO_ADJ'
						assert_no_params(opt_name, opt_params)
						general_props[:no_adjective] = true
					when 'NO_NOUN_NOUN'
						assert_no_params(opt_name, opt_params)
						general_props[:no_noun_noun] = true
					when 'NO_ATTR'
						assert_no_params(opt_name, opt_params)
						general_props[:no_attribute] = true
					when 'ONLY_SUBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:only_subj] = true
					when 'ONLY_OBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:only_obj] = true
					when 'OBJ_FREQ'
						assert_params_count(1, opt_name, opt_params)
						general_props[:obj_freq] = Integer(opt_params[0])
					when 'ATTR'
						attributes << parse_noun_object(opt_name, opt_params)
					else
						handle_option(opt_name, opt_params, general_props)
				end
			end
			Noun.new(text,gram_props,frequency,gender,general_props,number,person,animate,attributes,suffix)
		rescue WordParserError, WordValidationError, ArgumentError
			raise ParseError, "cannot parse '#{line}': #{$!.message}"
		end

		private
		STRING2GENDER = {'m'=>MASCULINE,'n'=>NEUTER,'f'=>FEMININE}
	end

	class VerbParser < WordParser
		def parse(text,gram_props,frequency,line)
			reflexive, suffix = false, nil
			objects = []
			general_props = {}
			new_parser.parse(line).each_option do |opt_name, opt_params|
				case opt_name
					when /^REFL(?:EXIVE|EX)?$/
						assert_no_params(opt_name, opt_params)
						reflexive = true
					when 'INF'
						if opt_params.nil?
							objects << InfinitiveObject.new
						elsif opt_params.size == 1
							objects << InfinitiveObject.new(opt_params[0])
						else
							raise WordParserError, "invalid format of #{opt_name}"
						end
					when 'ADJ'
						assert_no_params(opt_name, opt_params)
						objects << AdjectiveObject.new
					when 'SUFFIX'
						assert_params_count(1, opt_name, opt_params)
						suffix = opt_params[0]
					when 'OBJ_FREQ'
						assert_params_count(1, opt_name, opt_params)
						general_props[:obj_freq] = Integer(opt_params[0])
					when 'OBJ'
						objects << parse_noun_object(opt_name, opt_params)
					when 'ONLY_OBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:only_obj] = true
					when 'NOT_AS_OBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:not_as_object] = true
					else
						handle_option(opt_name, opt_params, general_props)
				end
			end
			Verb.new(text,gram_props,frequency,general_props,reflexive,
				objects,suffix)
		rescue WordParserError, WordValidationError, ArgumentError
			raise ParseError, "cannot parse '#{line}': #{$!.message}"
		end
	end

	class AdjectiveParser < WordParser
		def parse(text,gram_props,frequency,line)
			general_props = {}
			double = false
			attributes = []
			suffix = nil
			new_parser.parse(line).each_option do |opt_name, opt_params|
				case opt_name
					when 'NOT_AS_OBJ'
						assert_no_params(opt_name, opt_params)
						general_props[:not_as_object] = true
					when 'DOUBLE'
						assert_no_params(opt_name, opt_params)
						double = true
					when 'POSS'
						assert_no_params(opt_name, opt_params)
						double = true
					when 'ONLY_SING'
						assert_no_params(opt_name, opt_params)
						general_props[:only_singular] = true
					when 'ONLY_PL'
						assert_no_params(opt_name, opt_params)
						general_props[:only_plural] = true
					when 'SUFFIX'
						assert_params_count(1, opt_name, opt_params)
						suffix = opt_params[0]
					when 'ATTR'
						attributes << parse_noun_object(opt_name, opt_params)
					else
						handle_option(opt_name, opt_params, general_props)
				end
			end
			Adjective.new(text,gram_props,frequency,double,attributes,general_props,suffix)
		rescue WordParserError, WordValidationError
			raise ParseError, "cannot parse '#{line}': #{$!.message}"
		end
	end

	class AdverbParser < WordParser
		def parse(text,gram_props,frequency,line)
			general_props = {}
			new_parser.parse(line).each_option do |opt_name, opt_params|
				handle_option(opt_name, opt_params, general_props)
			end
			Adverb.new(text,gram_props,frequency,general_props)
		end
	end

	class OtherParser < WordParser
		def parse(text,gram_props,frequency,line)
			raise ParseError, "does not expect any grammar properties for other but got '#{gram_props}'" if !gram_props.empty?
			raise ParseError, "does not expect other properties for other but got '#{line}'" if line && line =~ /\w/
			Other.new(text,gram_props,frequency)
		end
	end

	# utility class
	class Words
		private_class_method :new
		def Words.get_parser(speech_part)
			parser_class = case speech_part
				when NOUN then NounParser
				when VERB then VerbParser
				when ADJECTIVE then AdjectiveParser
				when ADVERB then AdverbParser
				when OTHER then OtherParser
				else raise "unknown speech part: #{speech_part}"
			end
			parser_class.new
		end
	end
end
