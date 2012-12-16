# -*- encoding: utf-8 -*-

require './sentence'
require './configuration'
require './sentence_splitter'
require './randomized_choice'

require 'logger'

class Verse
	def initialize(sentence_mgr,conf)
		splitter = SentenceSplitter.new(conf)
		logger = conf.logger

		sentences = []
		sentences_text = []
		last_subject = nil
		while sentences_text.size < conf.lines_in_verse
			sentence = nil
			parts = nil
			MAX_TRIES.times do
				sentence = sentence_mgr.random_sentence
				if last_subject && check_chance(conf.implicit_subject_chance)
					sentence.implicit_subject = last_subject
				end
				text = sentence.write
				parts = splitter.split(text)
				if sentences_text.size + parts.size > conf.lines_in_verse
					# cannot add two sentences, because it's the last sentence - try again
					next
				end
				logger.debug "Split '#{parts.join(' | ')}'" if parts.size > 1
				break
			end
			sentences << sentence
			last_subject = sentence.subject
			parts.each do |p|
				sentences_text << p
				break if sentences_text.size >= conf.lines_in_verse
			end
		end
		sentences.each { |s| logger.debug "    #{s.debug_text}" }
		logger.debug ""
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

	MAX_TRIES = 6

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

		title_sentence_mgr = SentenceManager.new(dictionary,grammar,conf)
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
