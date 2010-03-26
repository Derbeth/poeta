#!/usr/bin/ruby -w

module Grammar

	NOUN = 'N'
	VERB = 'V'
	ADJECTIVE = 'A'
	SPEECH_PARTS = [NOUN,VERB,ADJECTIVE]

	NOMINATIVE,GENITIVE,DATIVE,ACCUSATIVE,INSTRUMENTAL,LOCATIVE,VOCATIVE = *(1..7)
	CASES = [NOMINATIVE,GENITIVE,DATIVE,ACCUSATIVE,INSTRUMENTAL,LOCATIVE,VOCATIVE]
		
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

		def inflect_noun(noun,form,*noun_props)
			unless form[:case]:
				raise ":case has to be passed '#{form[:case]}'"
			end
			noun_case = form[:case]
			noun_number = form[:number] || 1
			noun_case += 10 if noun_number == 2

			return noun if noun_case == NOMINATIVE
			
			if (@rules[NOUN].has_key?(noun_case)):
				@rules[NOUN][noun_case].each() do |rule|
					if rule.matches?(noun,*noun_props):
						return rule.inflect(noun,*noun_props)
					end
				end
			else
# 				puts "does not have noun case #{noun_case} #{@rules[NOUN].inspect}"
			end
			puts "warn: '#{noun}' not inflected for #{form.inspect} #{noun_props}"
			noun
		end
	end

end