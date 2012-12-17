# -*- encoding: utf-8 -*-

require './configuration'

class SentenceSplitter
	def initialize(conf)
		@conf = conf
	end

	def split(text)
		text = remove_unneeded_spaces(text)

		index = nil
		if text.length > @conf.max_line_length
			index = split_index(text)
		end

		parts = nil
		if index
			parts = [ text[0...index], text[index+1,text.size-1] ]
		else
			parts = [text]
		end

		parts.map { |p| remove_marks(p) }
	end

	private

	def remove_unneeded_spaces(text)
		t = text.dup
		t.gsub!(/ *\|\| */, '^')
		t.gsub!(/ *\| */, '|')
		t.gsub!(/ +/, ' ')
		t
	end

	def remove_marks(text)
		t = text.dup
		t.gsub!(/[|^]/, ' ')
		t
	end

	def split_index(text)
		split_index = text.index('^')
		return split_index if split_index

		stop_sign = text.include?('|') ? '|' : ' '
		stop_sign = stop_sign[0] # workaround for Ruby 1.8 problems
		half_len = text.length.div 2

		if text[half_len] == stop_sign
			return half_len
		end
		(1..half_len).each do |n|
			i = half_len - n
			if i >= 0
				return i if text[i] == stop_sign
			end
			i = half_len + n
			if i < text.length
				return i if text[i] == stop_sign
			end
		end

		return nil # impossible to split, no whitespace
	end
end
