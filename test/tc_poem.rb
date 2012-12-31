#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './poem'

include Grammar

class VerseTest < Test::Unit::TestCase
	class StubSentenceManager
		def initialize(*sentences)
			raise "should be enumerable" unless sentences.respond_to?(:each)
			@sentences=sentences
			@sentence_index=0
		end
		def <<(sentence)
			if sentence.is_a? String
				sentence = WithSubjectSentence.new(sentence)
			end
			@sentences << sentence
			self
		end
		def random_sentence
			retval = @sentences[@sentence_index]
			@sentence_index += 1 if @sentence_index < @sentences.size-1
			retval
		end
	end

	class NoSubjectSentence
		def write
			''
		end
		def subject
			nil
		end
		def debug_text
			''
		end
	end

	class WithSubjectSentence
		attr_accessor :subject
		def initialize(subject, rest=nil)
			@subject=Noun.new(subject,[],100,MASCULINE)
			@rest=rest
		end
		def write
			text = @subject.text
			text += ' ' + @rest if @rest
			text
		end
		def implicit_subject=(s)
			@subject = s
		end
		def debug_text
			''
		end
	end


	def test_find_subject
		conf = PoetryConfiguration.new
		conf.implicit_subject_chance = 0

		no = NoSubjectSentence.new
		some = WithSubjectSentence.new('some')
		other = WithSubjectSentence.new('other')
		empty = WithSubjectSentence.new('')

		verse1 = Verse.new(StubSentenceManager.new(no,no,no,no), conf)
		assert_equal(nil, verse1.subject)
		verse2 = Verse.new(StubSentenceManager.new(no,some,no,other), conf)
		assert_includes ['some', 'other'], verse2.subject.text
		verse3 = Verse.new(StubSentenceManager.new(some,no,no,no), conf)
		assert_equal('some', verse3.subject.text)
		verse4 = Verse.new(StubSentenceManager.new(no,no,no,some), conf)
		assert_equal('some', verse4.subject.text)
		verse5 = Verse.new(StubSentenceManager.new(empty,empty,empty,empty), conf)
		assert_equal(nil, verse5.subject)
	end

	def test_implicit_subject
		conf = PoetryConfiguration.new
		conf.implicit_subject_chance = 1

		no = NoSubjectSentence.new
		some = WithSubjectSentence.new('some')
		other = WithSubjectSentence.new('other')

		verse  = Verse.new(StubSentenceManager.new(no,some,other,other), conf)
		assert_equal "\nsome\nsome\nsome", verse.to_s
	end

	def test_sentence_splitting
		conf = PoetryConfiguration.new
		conf.max_line_length = 6
		conf.implicit_subject_chance = 0

		mgr = StubSentenceManager.new
		mgr << 'bird' << WithSubjectSentence.new('funny', 'and fantastic') << 'bug' << 'cow'
		verse = Verse.new(mgr, conf)
		assert_equal "bird\nfunny and\nfantastic\nbug", verse.to_s

		mgr = StubSentenceManager.new
		mgr << 'bird' << 'bug' << WithSubjectSentence.new('funny', '| and | fantastic') << 'cow'
		verse = Verse.new(mgr, conf)
		assert_equal "bird\nbug\nfunny and\nfantastic", verse.to_s

		mgr = StubSentenceManager.new
		mgr << WithSubjectSentence.new('funny', 'and || I') << 'bird' << 'bug' << 'cow'
		verse = Verse.new(mgr, conf)
		assert_equal "funny and\nI\nbird\nbug", verse.to_s

		# when last sentence is split into two, it should be discarded
		mgr = StubSentenceManager.new
		mgr << 'bird' << 'bug' << 'cow' << WithSubjectSentence.new('funny', 'and fantastic') << 'fox'
		verse = Verse.new(mgr, conf)
		assert_equal "bird\nbug\ncow\nfox", verse.to_s
		# should not include 'funny' because it has been rejected
		assert_includes %w{bird bug cow fox}, verse.subject.text

		# check subject handled properly
		mgr = StubSentenceManager.new
		mgr << NoSubjectSentence.new << WithSubjectSentence.new('funny', 'and fantastic') << NoSubjectSentence.new
		verse = Verse.new(mgr, conf)
		assert_equal 'funny', verse.subject.text
		assert_equal "\nfunny and\nfantastic\n", verse.to_s

		# check inflinite loop does not happen
		mgr = StubSentenceManager.new
		mgr << 'bird' << 'bug' << 'cow' << WithSubjectSentence.new('funny', 'and fantastic')
		verse = Verse.new(mgr, conf)
		assert_equal "bird\nbug\ncow\nfunny and", verse.to_s
	end
end
