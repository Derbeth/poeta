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
end