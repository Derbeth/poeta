#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './poem'
require './test/test_helper'

include Grammar

class PoemTest < Test::Unit::TestCase
	def test_empty
		conf = PoetryConfiguration.new
		conf.verses_number = 0
		assert_equal '', Poem.new('sentence_mgr', 'title_sentence_mgr', conf).text
	end

	def test_write
		srand
		conf = PoetryConfiguration.new
		conf.verses_number = 2
		conf.implicit_subject_chance = 0

		lines = (1..8).map { |n| "line #{n}" }
		sentence_mgr = StubSentenceManager.new(*lines)

		title_sentence_mgr = StubSentenceManager.new(NoSubjectSentence.new('fancy title'))

		poem = Poem.new(sentence_mgr, title_sentence_mgr, conf)
		expected_text = <<-END
"fancy title"

line 1
line 2
line 3
line 4

line 5
line 6
line 7
line 8
END
		expected_text.strip!
		assert_equal expected_text, poem.text
	end

	def test_non_breakable_space
		srand
		conf = PoetryConfiguration.new
		conf.verses_number = 1
		conf.implicit_subject_chance = 0

		lines = (1..4).map { |n| "line no~#{n}" }
		sentence_mgr = StubSentenceManager.new(*lines)

		title_sentence_mgr = StubSentenceManager.new(NoSubjectSentence.new('a~title'))

		poem = Poem.new(sentence_mgr, title_sentence_mgr, conf)
		expected_text = <<-END
"a title"

line no 1
line no 2
line no 3
line no 4
END
		expected_text.strip!
		assert_equal expected_text, poem.text
	end
end
