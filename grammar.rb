#!/usr/bin/ruby -w

module Grammar

	NOUN = 'N'
	VERB = 'V'
	ADJECTIVE = 'A'
	ADVERB = 'D'
	SPEECH_PARTS = [NOUN,VERB,ADJECTIVE,ADVERB]

	NOMINATIVE,GENITIVE,DATIVE,ACCUSATIVE,INSTRUMENTAL,LOCATIVE,VOCATIVE = *(1..7)
	CASES = [NOMINATIVE,GENITIVE,DATIVE,ACCUSATIVE,INSTRUMENTAL,LOCATIVE,VOCATIVE]
	CASE_NAMES = %w{M D C B N Ms W}
	CASE2STRING = Hash[CASES.zip CASE_NAMES]
	CASE_NAME_LEN = 2

	MASCULINE,FEMININE,NEUTER = *(1..3)
	GENDERS = [MASCULINE,FEMININE,NEUTER]
	GENDER_NAMES = %w{m f n}
	GENDER2STRING = Hash[GENDERS.zip GENDER_NAMES]

	SINGULAR,PLURAL = *(1..2)
	# all supported grammatical numbers (like singular or plural)
	NUMBERS = [SINGULAR,PLURAL]
	NUMBER_NAMES = %w{Sg Pl}
	NUMBER2STRING = Hash[NUMBERS.zip NUMBER_NAMES]

	class Grammar
		private_class_method :new
		def Grammar.describe_speech_part(s)
			case s
				when NOUN: 'noun'
				when VERB: 'verb'
				when ADJECTIVE: 'adjective'
				else raise "unknown speech part #{s}"
			end
		end
	end

	class Rule
		def initialize(remove,add,find,*required_props)
			@remove,@add,@find,@required_props=remove,add,find,required_props
			if !@required_props.empty? && !@required_props[0].kind_of?(String):
				raise "required properties don't contain strings: #{@required_props.inspect}"
			end
			@required_props ||= []
		end

		def matches?(word,*word_props)
			return false if word_props.nil?
			if word_props.empty? && word_props[0].kind_of?(String):
				raise "word properties don't contain strings: #{word_props.inspect}"
			end

			not_included = @required_props - word_props
			if !not_included.empty?:
# 				puts "#{word} does not have #{not_included.inspect} #{@required_props[0].class}"
				return false
			end
			word =~ /#{@find}$/
		end

		def inflect(word,*word_props)
			return word unless(matches?(word,*word_props))
			result = word.gsub(/#{@remove}$/, '')
			result + @add
		end
	end

	class AbstractGrammar
	end

	class PolishGrammar < AbstractGrammar

		def initialize()
			@rules={}
			SPEECH_PARTS.each do |part|
				@rules[part] = {}
			end
		end

		def read_rules(source)
			source.each_line do |line|
				speech_part,pattern,form,remove,add,condition = line.split(/\s+/)
				form = form.to_i
				find,required = condition.split(/\//)
				remove = '' if (remove == '0')
				required_props = [pattern]
				if required:
					required.split().each { |r| required_props << r }
				end
				unless (SPEECH_PARTS.include?(speech_part)):
					print "no such speed part: #{speech_part}"
					next
				end
				@rules[speech_part][form] ||= []
				@rules[speech_part][form] << Rule.new(remove,add,find,*required_props)
# 				puts "#{speech_part} #{form} #{@rules[speech_part][form].inspect}"
			end
		end

		def inflect_noun(noun,form,*gram_props)
			raise ":case has to be passed '#{form[:case]}'" unless form[:case]
			noun_case = form[:case]
			noun_number = form[:number] || 1
			noun_case += 10 if noun_number == 2

			return noun if noun_case == NOMINATIVE
			
			if (@rules[NOUN].has_key?(noun_case)):
				@rules[NOUN][noun_case].each() do |rule|
					if rule.matches?(noun,*gram_props):
						return rule.inflect(noun,*gram_props)
					end
				end
			else
# 				puts "does not have noun case #{noun_case} #{@rules[NOUN].inspect}"
			end
			puts "warn: '#{noun}' not inflected for #{form.inspect} #{gram_props}"
			noun
		end

		def inflect_adjective(adjective,form,*gram_props)
			raise ":case has to be passed '#{form[:case]}'" unless form[:case]
			raise ":gender has to be passed '#{form[:gender]}'" unless form[:gender]
			raise "wrong gender: #{form[:gender]}" unless GENDERS.include? form[:gender]
			form_id = form[:case]
			form_id += (form[:number]-1) * 10
			form_id += form[:gender] * 100
			puts "form id: #{form_id} #{@rules[ADJECTIVE].keys.inspect}"

			return adjective if form[:case] == NOMINATIVE

			if (@rules[ADJECTIVE].has_key?(form_id)):
				@rules[ADJECTIVE][form_id].each() do |rule|
					if rule.matches?(adjective,*gram_props):
						return rule.inflect(adjective,*gram_props)
					end
				end
			end
			puts "warn: '#{adjective}' not inflected for #{form.inspect} #{gram_props}"
			adjective
		end
	end

	class GrammarForm
		def self.pretty_print(form)
			parts = []
			parts << format_gender(form[:gender]) if (form[:gender])
			parts << format_number(form[:number]) if (form[:number])
			parts << format_case(form[:case]) if (form[:case])
			form.keys.sort_by{|s| s.to_s}.each do |key|
				if ![:gender,:number,:case].include?(key)
					parts << "#{key}=#{form[key]}"
				end
			end
			parts.join(' ')
		end

		def self.format_gender(gender)
			name = GENDER2STRING[gender]
			raise "unknown gender #{gender}" unless name
			name
		end

		def self.format_number(number)
			name = NUMBER2STRING[number]
			raise "unknown number #{number}" unless name
			name
		end

		def self.format_case(gram_case)
			name = CASE2STRING[gram_case]
			raise "unknown case #{gram_case}" unless name
			name.rjust(CASE_NAME_LEN)
		end
	end

end
