#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './sentence_manager'
require './configuration'

include Grammar

class SentenceBuilderTest < Test::Unit::TestCase
	def test_create_sentence
		dictionary_text = "N 100 foo\nN 100 bar"
		dictionary = ControlledDictionary.new
		dictionary.read dictionary_text
		dictionary.set_indices NOUN, [0, 1]
		grammar = PolishGrammar.new
		conf = PoetryConfiguration.new
		conf.double_noun_chance = 0

		builder = SentenceBuilder.new(dictionary,grammar,conf,'a ${NOUN} b',100)
		sentence1 = builder.create_sentence
		sentence2 = builder.create_sentence
		text1 = sentence1.write
		text2 = sentence2.write
		assert_equal('a foo b', text1)
		assert_equal('a bar b', text2)
		assert_nil(sentence1.subject)
		assert_nil(sentence2.subject)
	end
end

class SentenceManagerTest < Test::Unit::TestCase
	def test_read
		srand
		input = <<-END

#foo

100 okeee # inline comment
 10 also ok
-1 also bad negative

1 owaśtam
		END
		conf = PoetryConfiguration.new
		mgr = SentenceManager.new("dictionary",'grammar',conf)
		mgr.read(input)
		assert_equal(3, mgr.size)
		mgr.read(input)
		assert_equal(3, mgr.size)
		srand 1
		assert_equal('okeee', mgr.random_sentence.write)
	end

	def test_nonlatin_characters
		srand
		conf = PoetryConfiguration.new
		mgr = SentenceManager.new('dictionary','grammar',conf)
		mgr.read '10 ну, давай'
		assert_equal 'ну, давай', mgr.random_sentence.write
	end

	def test_get_random
		srand
		input = <<-END
0 never
1 sometimes
0 nevernever
2 is
0 neverever
		END
		conf = PoetryConfiguration.new
		mgr = SentenceManager.new("dictionary",'grammar',conf)
		mgr.read(input)
		assert_equal(5,mgr.size)
		100.times() do
			sentence = mgr.random_sentence.write
			assert(%w{sometimes is}.include?(sentence))
		end
	end

	def test_validation
		conf = PoetryConfiguration.new
		mgr = SentenceManager.new("dictionary",'grammar',conf)

		assert_raise(SentenceError) { mgr.read('10 ${SUBJ ${VERB}') }

		input = '10 ${SUBJ} ${VERB} ${SUBJ2}' # ok
		mgr.read(input)

		input = '10 ${ADJ}' # no such noun
		assert_raise(SentenceError) { mgr.read(input) }

		input = '10 ${NOUN2} ${ADJ}' # no such noun
		assert_raise(SentenceError) { mgr.read(input) }

		input = '10 ${NOUN} ${ADJ} ${NOUN2} {$ADJ2}' # ok
		mgr.read(input)

		input = '10 ${VERB}' # no such noun
		assert_raise(SentenceError) { mgr.read(input) }

		input = '10 ${NOUN2} ${VERB}' # wrong verb, no such noun
		assert_raise(SentenceError) { mgr.read(input) }

		input = '10 ${NOUN2} ${VERB2} ${OBJ}' # wrong object, no such noun
		assert_raise(SentenceError) { mgr.read(input) }

		input = '10 ${NOUN} ${VERB} ${NOUN2} {$VERB2}' # ok
		mgr.read(input)

		mgr.read('10 ${VERB(1)}')
		mgr.read('10 ${VERB(1)} ${OBJ}')
		assert_raise(SentenceError) { mgr.read('10 ${VERB} ${OBJ}') }
		mgr.read('10 ${SUBJ} ${VERB(a)}') # only warning
		mgr.read('10 ${SUBJ} ${VERB(14)}') # warning
		assert_raise(SentenceError) { mgr.read '10 ${VERB2.1.1}' }

		# unclosed brackets
		assert_raise(SentenceError) { mgr.read('10 ${SUBJ ${VERB} ${SUBJ2}') }
		assert_raise(SentenceError) { mgr.read('10 ${SUBJ} ${VERB ${SUBJ2}') }
		assert_raise(SentenceError) { mgr.read('10 ${SUBJ} ${VERB} ${SUBJ2') }
	end
end
