#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './configuration'
require './preprocessor'

include Poeta

class PreprocessorTest < Test::Unit::TestCase
	def setup
		srand
		@conf = PoetryConfiguration.new
		@conf.debug = true
		@preprocessor = Preprocessor.new(@conf)
	end

	def test_each_line
		input = <<-END
first line
second line

accented ąęń
		END
		index = 0
		@preprocessor.process(input).each_line do |line|
			assert_equal("first line\n", line) if index == 0
			assert_equal("second line\n", line) if index == 1
			assert_equal("\n", line) if index == 2
			assert_equal("accented ąęń\n", line) if index == 3
			flunk if index > 3
			index += 1
		end
	end

	def test_can_be_run_twice
		input1 = "line1.1\nline1.2\n"
		input2 = "line2.1\nline2.2\n"
		index = 0
		@preprocessor.process(input1).each_line do |line|
			assert_equal("line1.1\n", line) if index == 0
			assert_equal("line1.2\n", line) if index == 1
			flunk if index > 1
			index += 1
		end
		index = 0
		@preprocessor.process(input2).each_line do |line|
			assert_equal("line2.1\n", line) if index == 0
			assert_equal("line2.2\n", line) if index == 1
			flunk if index > 1
			index += 1
		end
	end

	def test_empty_input
		input = ""
		assert_equal "", as_string(@preprocessor.process(input))
	end

	def test_one_line_input
		input = "single line\n"
		assert_equal "single line\n", as_string(@preprocessor.process(input))
	end

	def test_unused_define
		input = <<-END
#define SINGULAR_YOU 1
I
you
		END
		assert_equal "I\nyou\n", as_string(@preprocessor.process(input))
	end

	def test_if_defined
		input = <<-END
#define SINGULAR_YOU 1
I
#if SINGULAR_YOU
thou
#endif
		END
		assert_equal "I\nthou\n", as_string(@preprocessor.process(input))
	end

	def test_if_undefined
		input = <<-END
I
#if SINGULAR_YOU
thou
#endif
		END
		assert_equal "I\n", as_string(@preprocessor.process(input))
	end

	def test_if_zero
		input = <<-END
#define SINGULAR_YOU 0
I
#if SINGULAR_YOU
thou
#endif
		END
		assert_equal "I\n", as_string(@preprocessor.process(input))
	end

	def test_define_twice
		input = <<-END
#define SINGULAR_YOU 0
#define SINGULAR_YOU 1
I
#if SINGULAR_YOU
thou
#endif
		END
		assert_equal "I\nthou\n", as_string(@preprocessor.process(input))
	end

	def test_more_defines
		input = <<-END
#define SINGULAR_YOU 1
#define USE_WE 0
#define USE_THEY 1
I
#if SINGULAR_YOU
thou
#endif
#if USE_WE
we
#endif
#if USE_THEY
they
#endif
		END
		assert_equal "I\nthou\nthey\n", as_string(@preprocessor.process(input))
	end

	def test_if_else_choosing_if
		input = <<-END
#define SINGULAR_YOU 1
I
#if SINGULAR_YOU
thou
#else
you
#endif
		END
		assert_equal "I\nthou\n", as_string(@preprocessor.process(input))
	end

	def test_if_else_choosing_else
		input = <<-END
#define SINGULAR_YOU 0
I
#if SINGULAR_YOU
thou
#else
you
#endif
		END
		assert_equal "I\nyou\n", as_string(@preprocessor.process(input))
	end

	def test_defined_vars_seen_in_all_files
		input1 = <<-END
#define SINGULAR_YOU 1
I
#if SINGULAR_YOU
thou
#endif
		END
		input2 = <<-END
no definitions here
#if SINGULAR_YOU
singular you
#endif
		END
		assert_equal "I\nthou\n", as_string(@preprocessor.process(input1))
		assert_equal "no definitions here\nsingular you\n", as_string(@preprocessor.process(input2))
	end

	def test_wrong_syntax_command_ignored
		input = <<-END
#define
I
#if SINGULAR_YOU
thou
#endif
		END
		assert_equal "I\n", as_string(@preprocessor.process(input))
	end

	def test_set_function
		input = <<-END
#define SINGULAR_YOU MY_FUNC(0.5)
I
#if SINGULAR_YOU
thou
#else
you
#endif
		END

		@preprocessor.set_function('MY_FUNC', lambda {|chance| 1})
		assert_equal "I\nthou\n", as_string(@preprocessor.process(input))
		@preprocessor = Preprocessor.new(@conf)
		@preprocessor.set_function('MY_FUNC', lambda {|chance| 0})
		assert_equal "I\nyou\n", as_string(@preprocessor.process(input))
	end

	def test_chance_function
		input = <<-END
#define SINGULAR_YOU CHANCE(0.5)
I
#if SINGULAR_YOU
thou
#else
you
#endif
		END

		assert_include ["I\nthou\n", "I\nyou\n"], as_string(@preprocessor.process(input))
	end

	def test_function_wrong_name
		input = <<-END
#define SINGULAR_YOU CHANCES(0.5)
I
#if SINGULAR_YOU
thou
#endif
		END

		assert_equal "I\n", as_string(@preprocessor.process(input))
	end

	def test_function_wrong_syntax
		input = <<-END
#define SINGULAR_YOU CHANCE(0.5
I
#if SINGULAR_YOU
thou
#endif
		END

		assert_equal "I\n", as_string(@preprocessor.process(input))
	end

	def test_function_wrong_args
		input = <<-END
#define SINGULAR_YOU CHANCE()
#define USE_WE CHANCE(0.5, 3)
I
#if SINGULAR_YOU
thou
#endif
#if USE_WE
we
#endif
		END

		assert_equal "I\n", as_string(@preprocessor.process(input))
	end

	def test_reading_from_wrong_file
		input_path = File.expand_path('wrong_preprocessor_commands.c', File.dirname(__FILE__))
		assert File.exists?(input_path)
		assert_equal "", as_string(@preprocessor.process(File.open(input_path)))
	end

	private

	def as_string(output)
		lines = []
		output.each_line { |line| lines << line }
		lines.join
	end
end
