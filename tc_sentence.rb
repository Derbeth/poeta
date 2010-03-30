#!/usr/bin/ruby -w
require 'test/unit'

require 'sentence'

include Grammar

class SentenceTest < Test::Unit::TestCase
	def test_trim
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)

		sentence = Sentence.new(dictionary,'')
		assert_equal('', sentence.write)
		sentence = Sentence.new(dictionary,'  ')
		assert_equal('', sentence.write)
		sentence = Sentence.new(dictionary,' ${VERB} ${SUBJ}   ${SUBJ} ')
		assert_equal('foo foo', sentence.write)
	end

	def test_handle_subject
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)

		sentence = Sentence.new(dictionary,'a ${SUBJ} b')
		text = sentence.write
		assert_equal('a foo b', text)
		assert_equal('foo', sentence.subject.text)

		srand 1
		dictionary2_text = "N 100 foo\nN 100 bar"
		dictionary2 = Dictionary.new
		dictionary2.read(dictionary2_text)
		sentence = Sentence.new(dictionary2,'a ${SUBJ} ${SUBJ2} b')
		text = sentence.write
		assert_equal('a foo bar b', text)
		assert_equal('foo', sentence.subject.text)
	end

	def test_handle_adjective
		dictionary_text = "N 100 stuff\nA 100 cool"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)

		sentence = Sentence.new(dictionary,'?${ADJ} ${NOUN}?')
		assert_equal('?cool stuff?', sentence.write)

		srand 1
		dictionary2_text = "N 100 stuff\nN 100 things\nA 100 cool\nA 100 bad"
		dictionary2 = Dictionary.new
		dictionary2.read(dictionary2_text)

		sentence = Sentence.new(dictionary2,'${ADJ1} ${NOUN} ${ADJ2} ${NOUN2}')
		assert_equal('cool stuff bad things', sentence.write)
		sentence = Sentence.new(dictionary2,'${NOUN1} ${ADJ1} ${NOUN2} ${ADJ1}')
		assert_equal('things bad stuff bad', sentence.write)
	end

	def test_handle_verb
		srand 1
		dictionary_text = "N 100 stuff\nN 100 things\nV 100 goes\nV 100 suck"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)

		sentence = Sentence.new(dictionary,'${NOUN} ${VERB} ${NOUN2} ${VERB2}')
		assert_equal('stuff goes things suck', sentence.write)
	end

	def test_handle_empty_dictionary
		dictionary = Dictionary.new
		sentence = Sentence.new(dictionary,'${NOUN} ${ADJ} ${VERB}')
		assert_equal('', sentence.write.strip)
	end
end

class SentenceBuilderTest < Test::Unit::TestCase
	def test_create_sentence
		srand 1
		dictionary_text = "N 100 foo\nN 100 bar"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)

		builder = SentenceBuilder.new(dictionary,'a ${NOUN} b',100)
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
		input = <<-END

#foo

100 okeee
 10 also okee
-1 also bad negative

1 owaśtam
		END
		mgr = SentenceManager.new("dictionary")
		mgr.read(input)
		assert_equal(3, mgr.size)
		mgr.read(input)
		assert_equal(3, mgr.size)
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
		mgr = SentenceManager.new("dictionary")
		mgr.read(input)
		assert_equal(5,mgr.size)
		100.times() do
			sentence = mgr.random_sentence.write
			assert(%w{sometimes is}.include?(sentence))
		end
	end

	def test_validation
		mgr = SentenceManager.new("dictionary")
		input = '10 ${SUBJ} ${VERB} ${SUBJ}' # double subject
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${SUBJ} ${VERB} ${NOUN}' # double noun/subject
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${SUBJ} ${VERB} ${SUBJ2}' # ok
		mgr.read(input)

		input = '10 ${ADJ}' # no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN2} ${ADJ}' # no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN} ${ADJ} ${NOUN2} {$ADJ2}' # ok
		mgr.read(input)

		input = '10 ${VERB}' # no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN2} ${VERB}' # no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN} ${VERB} ${NOUN2} {$VERB2}' # ok
		mgr.read(input)
	end
end
