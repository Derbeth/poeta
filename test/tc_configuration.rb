#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './configuration'

class PoetryConfigurationTest < Test::Unit::TestCase
	def setup
		@conf = PoetryConfiguration.new
	end

	def test_logger
		assert !@conf.debug
		logger = @conf.logger
		logger.debug "Testing logger"
		old_level = logger.level

		@conf.debug = true
		logger = @conf.logger
		assert_not_equal old_level, logger.level
		logger.debug "Testing logger once again"
	end

	def test_verses_number
		# test that the default value passes validation :)
		@conf.verses_number = @conf.verses_number
	end

	def test_lines_in_verse
		@conf.lines_in_verse = @conf.lines_in_verse
	end

	def test_max_line_length
		@conf.max_line_length = @conf.max_line_length
	end

	CHANCES = [:implicit_subject_chance, :double_adj_chance, :double_noun_chance,
			:other_word_chance, :object_adj_chance]
	CHANCES.each do |attr|
		define_method "test_#{attr}".to_sym do
			setter = "#{attr}=".to_sym
			@conf.send(setter, @conf.send(attr))
			@conf.send(setter, 0.3)
			assert_raise(ArgumentError) { @conf.send(setter, 50) }
			assert_equal 0.3, @conf.send(attr)
		end
	end
end
