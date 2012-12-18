#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './sentence_splitter'

class SentenceSplitterTest < Test::Unit::TestCase
	def setup
		@conf = PoetryConfiguration.new
		@splitter = SentenceSplitter.new(@conf)
	end

	def test_split
		@conf.max_line_length = 10

		# 1. no split if no spaces
		assert_equal [''], @splitter.split('')
		assert_equal ['a'], @splitter.split('a')
		assert_equal ['a'*10], @splitter.split('a'*10)
		assert_equal ['a'*13], @splitter.split('a'*13)

		# 2. no split if too short
		assert_equal ['aaaaa bbbb'], @splitter.split('aaaaa bbbb')
		assert_equal ['a b'], @splitter.split('a           b')

		# 3. split on space
		# border case: 1 character more than string length
		assert_equal ['aaaaaaa', 'bbb'],  @splitter.split('aaaaaaa bbb')
		assert_equal ['aaa', 'bbbbbbb'],  @splitter.split('aaa bbbbbbb')
		assert_equal ['aaaaaaa,', 'bbb'], @splitter.split('aaaaaaa, bbb')
		assert_equal ['aaaaaaaaaa', 'b'], @splitter.split('aaaaaaaaaa b')
		assert_equal ['a', 'bbbbbbbbbb'], @splitter.split('a bbbbbbbbbb')
		assert_equal ['aaaaaaa', 'bbbb ccc'], @splitter.split('aaaaaaa bbbb ccc')
		assert_equal ['aaaaaaa,', 'bbbb ccc'], @splitter.split('aaaaaaa, bbbb ccc')
		assert_equal ['aaaaaaa', 'bbbb ccc'], @splitter.split('aaaaaaa bbbb       ccc')

		# 4. split on forced sign
		assert_equal ['aaaaaa bbbb', 'ccc'], @splitter.split('aaaaaa bbbb || ccc')
		assert_equal ['aaaaaa bbbb', 'ccc'], @splitter.split('aaaaaa | bbbb || ccc')

		# 5. split on normal split sign
		assert_equal ['aaaaaa', 'bbbb ccc'], @splitter.split('aaaaaa | bbbb | ccc')
		assert_equal ['aaaaaa,', 'bbbb, ccc'], @splitter.split('aaaaaa, | bbbb, | ccc')
	end

	def test_typography
		@conf.max_line_length = 10
		# should not leave dangling single-letter words like 'w' at the end
		assert_equal ['na dworcu', 'w KutnieKutnieKutnie'], @splitter.split('na dworcu w KutnieKutnieKutnie')

		# check that this does not prevent sentences to be splitted
		['a b c d e f g h', 'A B C D E F G, H', '1, B C D E F G H'].each do |s|
			parts = @splitter.split(s)
			assert parts.size > 1, "Too long string needs to be splitted: #{parts}"
			parts.each do |p|
				assert p.size > 2, "Very suboptimal split: #{parts.inspect}"
			end
			puts "test_typography: Splitted into #{parts}"
		end
	end

	def test_non_breakable_space
		@conf.max_line_length = 10
		assert_equal ['aaaaaa', 'be cc'], @splitter.split('aaaaaa be~cc')
	end

	def test_does_not_modify_arg
		@conf.max_line_length = 5
		str = 'aaaa bbbb'
		assert_equal ['aaaa', 'bbbb'], @splitter.split(str)
		assert_equal 'aaaa bbbb', str
	end
end
