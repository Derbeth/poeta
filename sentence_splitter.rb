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

		# in case nothing better is found, this index will be used to split
		last_resort_index = nil

		if text[half_len] == stop_sign
			if split_looks_nice?(text, half_len)
				return half_len
			else
				last_resort_index ||= half_len
			end
		end
		(1..half_len).each do |n|
			i = half_len - n
			if i >= 0 && text[i] == stop_sign
				if split_looks_nice?(text, i)
					return i
				else
					last_resort_index ||= i
				end
			end
			i = half_len + n
			if i < text.length && text[i] == stop_sign
				if split_looks_nice?(text, i)
					return i
				else
					last_resort_index ||= i
				end
			end
		end

		@conf.logger.debug "Using last resort to split '#{text}'" if last_resort_index
		return last_resort_index
	end

	# checks if split on given index would look good from typographical point of view
	def split_looks_nice?(text,index)
		if text[index-1] == ','
			index -= 1
		end

		just_before = nil
		if index > 1
			just_before = text[index-2,2]
		else
			just_before = text[index-1,1]
		end

		just_before !~ /^ *\w$/
	end
end
