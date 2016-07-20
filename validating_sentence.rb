# -*- encoding: utf-8 -*-

require './base_sentence'

class ValidatingSentence < BaseSentence
	def initialize(dictionary,grammar,conf,pattern)
		super(dictionary,grammar,conf,pattern)
	end

	def validate
		@noun_occurs = {}
		text = self.write
		if text =~ /\$\{\S+/
			raise SentenceError, "syntax error near '#{$&}' - cannot handle this placeholder"
		end
	end

	protected

	def handle_subject(full_match,noun_index,norm_index,parsed_opts)
		common_handle_noun(full_match,noun_index,norm_index,parsed_opts)
	end

	def handle_noun(full_match,noun_index,norm_index,parsed_opts)
		common_handle_noun(full_match,noun_index,norm_index,parsed_opts)
	end

	def handle_verb(full_match,noun_index,norm_index,parsed_opts)
		if parsed_opts[:form]
			@noun_occurs[noun_index] ||= 0
			@noun_occurs[noun_index] += 1
		end
		check_noun_occur(full_match, noun_index)
		'verb'
	end

	def handle_adjective(full_match,noun_index,norm_index,parsed_opts)
		check_noun_occur(full_match, noun_index)
		'adjective'
	end

	def handle_object(full_match,noun_index,norm_index,parsed_opts)
		check_noun_occur(full_match, noun_index)
		'object'
	end

	def handle_adverb(full_match,noun_index,norm_index,parsed_opts)
		'adverb'
	end

	def handle_other(full_match,noun_index,norm_index,parsed_opts)
		'other'
	end

	private

	def common_handle_noun(full_match,noun_index,norm_index,parsed_opts)
		@noun_occurs[noun_index] ||= 0
		@noun_occurs[noun_index] += 1
		'noun'
	end

	def check_noun_occur(full_match, noun_index)
		unless @noun_occurs.include? noun_index
			raise SentenceError, "undefined noun referenced from #{full_match} in '#{@pattern}'"
		end
	end

end
