# -*- encoding: utf-8 -*-

require './configuration'
require './sentence_manager'
require './verse'

require 'logger'

class Poem
	def initialize(sentence_mgr,title_sentence_mgr,conf)
		if conf.verses_number == 0
			@text = ''
			return
		end
		verses = []
		conf.verses_number.times { verses << Verse.new(sentence_mgr,conf) }

		title_sentence = title_sentence_mgr.random_sentence
		title_subject = verses[0].subject
		title_sentence.subject = title_subject if title_subject
		title = title_sentence.write

		@title = title
		@text = "\"#{@title}\"\n\n#{verses.join("\n\n")}"
		@text.gsub!('~', ' ')
	end

	def text
		@text
	end
end
