# -*- encoding: utf-8 -*-

require './sentence'
require './configuration'
require './randomized_choice'

class Verse
	def initialize(sentence_mgr,conf)
		sentences = []
		sentences_text = []
		last_subject = nil
		conf.lines_in_verse.times do
			sentence = sentence_mgr.random_sentence
			if last_subject && check_chance(conf.implicit_subject_chance)
				sentence.implicit_subject = last_subject
			end
			sentences << sentence
			sentences_text << sentence.write
			last_subject = sentence.subject
		end
		@subject = find_subject(sentences)
		@text = sentences_text.join("\n")
	end

	# gets subject (noun) representing the verse
	def subject
		@subject
	end

	def to_s
		@text
	end

	private

	include ChanceChecker

	def find_subject(sentences)
		subjects = []
		sentences.each do |sentence|
			subjects << sentence.subject if sentence.subject && sentence.subject.text != ''
		end
		return nil if subjects.empty?
		subjects[rand(subjects.size)]
	end
end

class Poem
	def initialize(dictionary,grammar,sentence_mgr,conf)
		if conf.verses_number == 0
			@text = ''
			return
		end
		verses = []
		conf.verses_number.times { verses << Verse.new(sentence_mgr,conf) }

		title_sentence_mgr = SentenceManager.new(dictionary,grammar)
		title_sentences_defs = <<-END
60 ${SUBJ(NE,IG_ONLY)}
40 ${ADJ} ${SUBJ(NE,IG_ONLY)}
 5 ${SUBJ(NE,IG_ONLY)} ${ADJ}
10 ${VERB(1)} ${OBJ}
 5 ${VERB(11)} ${OBJ}
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
