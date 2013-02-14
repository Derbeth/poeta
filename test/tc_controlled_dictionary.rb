#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './controlled_dictionary'

include Grammar

class ControlledDictionaryTest < Test::Unit::TestCase
	def setup
		srand
		dictionary_text = "N 100 first\nN 100 second\nN 0 impossible\nV 100 go\nV 100 run"
		@dictionary = ControlledDictionary.new
		@dictionary.read dictionary_text
	end

	def test_disallows_wrong_indices
		# no such speech part
		assert_raise(ArgumentError) { @dictionary.set_indices(666, [1]) }
		# wrong second arg
		assert_raise(ArgumentError) { @dictionary.set_indices(NOUN, NOUN) }
		# there are no adverbs in this dictionary
		assert_raise(ArgumentError) { @dictionary.set_indices(ADVERB, [1]) }
		# negative index
		assert_raise(ArgumentError) { @dictionary.set_indices(NOUN, [0, -1, 2]) }
		# too big index
		assert_raise(ArgumentError) { @dictionary.set_indices(VERB, [2]) }
		# now test a hash
		assert_raise(ArgumentError) { @dictionary.set_indices(NOUN => [0], VERB=>[2]) }
	end

	def test_correct
		@dictionary.set_indices NOUN, [0, 2, 2, 2]
		@dictionary.set_indices VERB, [1, 1, 1, 0]

		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'impossible', @dictionary.get_random(NOUN).text
		assert_equal 'impossible', @dictionary.get_random(NOUN).text
		assert_equal 'impossible', @dictionary.get_random(NOUN).text
		assert_not_nil @dictionary.get_random(NOUN) # some random
		assert_not_nil @dictionary.get_random(NOUN) # some random
		assert_not_nil @dictionary.get_random(NOUN) # some random

		assert_equal 'run', @dictionary.get_random(VERB).text
		assert_equal 'run', @dictionary.get_random(VERB).text
		assert_equal 'run', @dictionary.get_random(VERB).text
		assert_equal 'go', @dictionary.get_random(VERB).text
		assert_not_nil @dictionary.get_random(VERB) # some random
		assert_not_nil @dictionary.get_random(VERB) # some random
		assert_not_nil @dictionary.get_random(VERB) # some random

		assert_nil @dictionary.get_random(ADVERB)

		# supply with some more indices, should stop serving random numbers
		@dictionary.set_indices NOUN, [1, 1]

		assert_equal 'second', @dictionary.get_random(NOUN).text
		assert_equal 'second', @dictionary.get_random(NOUN).text
		assert_not_nil @dictionary.get_random(NOUN) # some random now
	end

	def test_set_indices_hash
		@dictionary.set_indices(NOUN => [0,2,2,2], VERB => [1,1,1,0])
		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'run', @dictionary.get_random(VERB).text
		@dictionary.set_indices({NOUN => [0,2,2,2], VERB => [1,1,1,0]})
		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'run', @dictionary.get_random(VERB).text
	end

	def test_interrupt
		@dictionary.set_indices NOUN, [1, 1, 1, 1, 1]

		assert_equal 'second', @dictionary.get_random(NOUN).text
		assert_equal 'second', @dictionary.get_random(NOUN).text
		assert_equal 'second', @dictionary.get_random(NOUN).text

		# we interrupt now!
		@dictionary.set_indices NOUN, [0, 0, 0, 0, 0]

		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'first', @dictionary.get_random(NOUN).text
		assert_equal 'first', @dictionary.get_random(NOUN).text
	end
end
