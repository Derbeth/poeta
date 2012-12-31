#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './verse'
require './test/test_helper'

include Grammar

class VerseTest < Test::Unit::TestCase
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

	def test_lines_in_verse_configurable
		conf = PoetryConfiguration.new
		conf.implicit_subject_chance = 0
		conf.lines_in_verse = 2

		verse = Verse.new(StubSentenceManager.new('first line', 'second line', 'third line'), conf)
		assert_equal "first line\nsecond line", verse.to_s
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
