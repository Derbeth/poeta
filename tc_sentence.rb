#!/usr/bin/ruby -w
require 'test/unit'

require 'sentence'

include Grammar

class SentenceTest < Test::Unit::TestCase
	def test_handle_subject
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)

		sentence = Sentence.new(dictionary,'a ${SUBJ} b')
		text = sentence.write
		assert_equal('a foo b', text)
		assert_equal('foo', sentence.subject.text)
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

	def test_double_subject
		input = '10 ${SUBJ} ${VERB} ${SUBJ}'
		mgr = SentenceManager.new("dictionary")
		assert_raise(RuntimeError) { mgr.read(input) }
	end
end
