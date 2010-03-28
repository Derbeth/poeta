#!/usr/bin/ruby -w
require 'test/unit'

require 'sentence'

include Grammar

class SentenceManagerTest < Test::Unit::TestCase
	def test_read
		input = <<-END

#foo

100 okeee
 100 bad cause indented
-1 also bad negative

1 owaśtam
		END
		mgr = SentenceManager.new("dictionary")
		mgr.read(input)
		assert_equal(2, mgr.size)
		mgr.read(input)
		assert_equal(2, mgr.size)
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
end
