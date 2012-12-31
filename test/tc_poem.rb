#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './poem'

include Grammar

class PoemTest < Test::Unit::TestCase
	def test_write
		dictionary = 'dictionary'
		grammar = 'grammar'
		conf = PoetryConfiguration.new
	end
end
