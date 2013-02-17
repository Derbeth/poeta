#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './smart_random_dictionary'

include Grammar

class SmartRandomDictionaryTest < Test::Unit::TestCase
	def test_correct
		dictionary_text = "N 1 foo\nN 1 bar"
		sum_freqs = 2
		dictionary = Dictionary.new
		smart_dictionary = SmartRandomDictionary.new(1)
		dictionary.read(dictionary_text)
		smart_dictionary.read(dictionary_text)
		srand 1
		assert_equal(1,rand(sum_freqs))
		assert_equal(1,rand(sum_freqs))
		assert_equal(0,rand(sum_freqs))
		100.times do
			srand 1
			assert_equal('bar', dictionary.get_random(NOUN).text)
			assert_equal('bar', dictionary.get_random(NOUN).text)
			srand 1
			assert_equal('bar', smart_dictionary.get_random(NOUN).text)
			assert_equal('foo', smart_dictionary.get_random(NOUN).text)
		end
	end
end
