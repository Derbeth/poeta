# -*- encoding: utf-8 -*-

require './sentence'
require './configuration'
require './sentence_splitter'

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
