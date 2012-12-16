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
		assert_equal ['aaaaa bbbb'], @splitter.split('aaaaa bbbb')

		# 2. split on space
		# border case: 1 character more than string length
		assert_equal ['aaaaaaa', 'bbb'],  @splitter.split('aaaaaaa bbb')
		assert_equal ['aaa', 'bbbbbbb'],  @splitter.split('aaa bbbbbbb')
		assert_equal ['aaaaaaa,', 'bbb'], @splitter.split('aaaaaaa, bbb')
		assert_equal ['aaaaaaaaaa', 'b'], @splitter.split('aaaaaaaaaa b')
		assert_equal ['a', 'bbbbbbbbbb'], @splitter.split('a bbbbbbbbbb')
		assert_equal ['aaaaaaa', 'bbbb ccc'], @splitter.split('aaaaaaa bbbb ccc')
		assert_equal ['aaaaaaa,', 'bbbb ccc'], @splitter.split('aaaaaaa, bbbb ccc')
		assert_equal ['aaaaaaa', 'bbbb ccc'], @splitter.split('aaaaaaa bbbb       ccc')

		# 3. split on forced sign
		assert_equal ['aaaaaa bbbb', 'ccc'], @splitter.split('aaaaaa bbbb || ccc')
		assert_equal ['aaaaaa bbbb', 'ccc'], @splitter.split('aaaaaa | bbbb || ccc')

		# 4. split on normal split sign
		assert_equal ['aaaaaa', 'bbbb ccc'], @splitter.split('aaaaaa | bbbb | ccc')
		assert_equal ['aaaaaa,', 'bbbb, ccc'], @splitter.split('aaaaaa, | bbbb, | ccc')
	end
end
