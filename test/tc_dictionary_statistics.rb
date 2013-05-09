#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './dictionary_statistics'

class DictionaryTest < Test::Unit::TestCase
	def setup
		@dict = Grammar::Dictionary.new
		@dict.read <<-END
N 3 cat
N 1 cat Pl                 # two same nouns
N 1 mouse
N 1 "" PERSON(1)           # empty text
V 2 look OBJ(after,2)
V 1 look OBJ(for,2)
A 1 smart
		END
	end

	def test_default_print
		DictionaryStatistics.new.print(@dict)
	end

	def test_sort_key_and_order
		DictionaryStatistics.new.print @dict, :sort_key => :freq, :sort_order => :desc
	end

	def test_raises_exception_on_wrong_sort_key
		DictionaryStatistics.new.print @dict, :sort_key => :wrongsortkey
		flunk "Expected to raise an exception"
	rescue => e
		assert_includes e.to_s, 'wrongsortkey'
	end

	def test_raises_exception_on_wrong_sort_order
		DictionaryStatistics.new.print @dict, :sort_order => :wrongorder
		flunk "Expected to raise an exception"
	rescue => e
		assert_includes e.to_s, 'wrongorder'
	end
end
