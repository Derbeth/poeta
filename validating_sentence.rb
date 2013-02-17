# -*- encoding: utf-8 -*-

require './base_sentence'

class ValidatingSentence < BaseSentence
	def initialize(dictionary,grammar,conf,pattern)
		super(dictionary,grammar,conf,pattern)
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

end
