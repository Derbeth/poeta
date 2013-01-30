#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './parser'

include Poeta

class ParserTest < Test::Unit::TestCase
	def test_empty_string
		parser = Parser.new
		options_count = 0
		parser.parse("").each_option do
			options_count += 1
		end
	end

	def test_single_option_no_params
		parser = Parser.new
		options = []
		parser.parse("FOO").each_option do |opt,pars|
			assert_nil pars
			options << opt
		end
		assert_equal ["FOO"], options
	end

	def test_single_option_single_param
		parser = Parser.new(Parser::COMMA)
		options, params = run_parse(parser, "FOO(bar)")
		assert_equal ["FOO"], options
		assert_equal [["bar"]], params
	end

	def test_single_option_single_param_whitespace
		parser = Parser.new
		options, params = run_parse(parser, "  FOO( bar ) ")
		assert_equal ["FOO"], options
		assert_equal [["bar"]], params
	end

	def test_options_with_params_spaces
		parser = Parser.new(Parser::SPACE)
		options, params = run_parse(parser, " FOO(a,b c) BAR(d) ")
		assert_equal ["FOO", "BAR"], options
		assert_equal [["a","b c"], ["d"]], params
	end

	def test_options_with_params_commas
		parser = Parser.new(Parser::COMMA)
		options, params = run_parse(parser, " FOO(a,b c,d),BAR, BAZ(e) ")
		assert_equal ["FOO", "BAR", "BAZ"], options
		assert_equal [["a", "b c","d"], nil, ["e"]], params
	end

	def test_nested_options_spaces
		parser = Parser.new(Parser::SPACE)
		options, params = run_parse(parser, " INF OBJ(2, TAKES_ONLY(one,two), TAKES_NO(three ) ) SEMANTIC(good) ")
		assert_equal ["INF", "OBJ", "SEMANTIC"], options
		assert_equal [nil, ["2", "TAKES_ONLY(one,two)", "TAKES_NO(three )"], ["good"]], params
	end

	def test_does_not_modify_input
		input = " foo "
		Parser.new.parse(input)
		assert_equal " foo ", input
	end

	def test_unbalanced_braces_cause_exception
		assert_raise(ParserError) { Parser.new.parse("FOO(BAR()") }
	end

	def test_empty_braces_cause_exception
		assert_raise(ParserError) { Parser.new.parse("FOO()  ()") }
	end

	def test_raise_exception_on_wrong_separator
		assert_raise(ArgumentError) { Parser.new(1243).parse("foo") }
	end

	private

	def run_parse(parser, string)
		options, params = [], []
		parser.parse(string).each_option do |opt,pars|
			options << opt
			params << pars
		end
		return [options, params]
	end
end
