# -*- encoding: utf-8 -*-

require './configuration'
require './sentence_manager'
require './verse'

require 'logger'

class Poem
	def initialize(dictionary,grammar,sentence_mgr,conf)
		if conf.verses_number == 0
			@text = ''
			return
		end
		verses = []
		conf.verses_number.times { verses << Verse.new(sentence_mgr,conf) }

		title_sentence_mgr = SentenceManager.new(dictionary,grammar,conf)
		title_sentences_defs = <<-END
60 ${SUBJ(NE,IG_ONLY)}
40 ${ADJ} ${SUBJ(NE,IG_ONLY)}
 5 ${SUBJ(NE,IG_ONLY)} ${ADJ}
10 ${VERB(1)} ${OBJ}
 5 ${VERB(11)} ${OBJ}
 4 ${VERB(2,IMP)} ${OBJ}
10 ***
		END
		title_sentence_mgr.read(title_sentences_defs)

		title_sentence = title_sentence_mgr.random_sentence
		title_subject = verses[0].subject
		title_sentence.subject = title_subject if title_subject
		title = title_sentence.write

		@title = title
		@text = "\"#{@title}\"\n\n#{verses.join("\n\n")}"
	end

	def text
		@text
	end
end
