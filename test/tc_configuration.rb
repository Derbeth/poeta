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

	def test_implicit_subj_adj
		@conf.implicit_subj_adj = @conf.implicit_subj_adj
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

	def test_read_incomplete
		source = <<-END
verses_number: 2
implicit_subject_chance: 0.31
		END
		assert_equal 4, @conf.lines_in_verse

		assert_equal true, @conf.read(source)
		assert_equal 2, @conf.verses_number
		assert_equal 0.31, @conf.implicit_subject_chance
		assert_equal 4, @conf.lines_in_verse # should not be changed after read
	end

	def test_read_rubbish
		source = "4A@##fa25462ą"
		assert_equal 4, @conf.lines_in_verse

		assert_equal false, @conf.read(source)
		assert_equal 4, @conf.lines_in_verse # should not be changed after read
	end

	def test_read_rubbish_from_file
		assert_equal 4, @conf.lines_in_verse

		rubbish_path = File.expand_path('rubbish', File.dirname(__FILE__))
		assert File.exists?(rubbish_path)
		assert_equal false, @conf.read(File.open(rubbish_path))
		assert_equal 4, @conf.lines_in_verse # should not be changed after read
	end

	def test_read_invalid_values
		source = <<-END
lines_in_verse: 1
implicit_subject_chance: 33
verses_number: 3
other_word_chance: 22%
		END
		assert_equal 0.25, @conf.implicit_subject_chance
		assert_equal 0.3, @conf.other_word_chance

		@conf.read(source)
		assert_equal 0.25, @conf.implicit_subject_chance #should not be overwritten by invalid values
		assert_equal 0.3, @conf.other_word_chance
		assert_equal 1, @conf.lines_in_verse # should read as much as it could
		assert_equal 3, @conf.verses_number
	end

	def test_read_empty_with_comments
		source = <<-END
# some comments

		END
		# should not report errors
		assert_equal true, @conf.read(source)
	end

	def test_transient_attributes_untouched
		source = <<-END
logger: "foo"
		END
		@conf.read source
		@conf.logger.debug "Still working!"
	end

	def test_summary
		@conf.implicit_subject_chance = 0.535
		assert_match(/0\.535/, @conf.summary)
	end
end
