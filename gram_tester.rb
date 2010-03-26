#!/usr/bin/ruby -w
require 'test/unit'

require 'grammar'

include Grammar

class PolishGrammarTest < Test::Unit::TestCase
	def test_rule
		rule1 = Rule.new('','a','g','A')
		rule2 = Rule.new('','u','.','A')
		rule3 = Rule.new('t','cie','t','A')
		
		assert(!rule1.matches?('bug'))
		assert(!rule1.matches?('bug','a'))
		assert(rule1.matches?('bug','A'))
		
		assert(!rule2.matches?('bug'))
		assert(!rule2.matches?('bug','a'))
		assert(rule2.matches?('bug','A'))
		
		assert(!rule3.matches?('bug'))
		
		assert_equal('buga', rule1.inflect('bug', 'A'))
		assert_equal('buga', rule1.inflect('bug', 'B', 'A'))
		assert_equal('buga', rule1.inflect('bug', 'A', 'B'))
		assert_equal('bugu', rule2.inflect('bug', 'A'))
		assert_equal('bug', rule3.inflect('bug', 'A'))
		
		assert_equal('kocie', rule3.inflect('kot', 'A'))
	end

	def test_grammar
		grammar = PolishGrammar.new
		grammar.read_rules(File.open('test.aff'))

		assert_equal('kot', grammar.inflect_noun('kot', :case=>LOCATIVE))
		assert_equal('kot', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'Z'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'A'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'Z', 'A'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE, :count=>1}, 'A'))
		assert_equal('kot', grammar.inflect_noun('kot', {:case=>LOCATIVE, :count=>2}, 'A'))

		assert_equal('łobu', grammar.inflect_noun('łob', {:case=>LOCATIVE}, 'A'))
		assert_equal('waltie', grammar.inflect_noun('walt', {:case=>LOCATIVE}, 'X', 'A'))
		assert_equal('waltie', grammar.inflect_noun('walt', {:case=>LOCATIVE}, 'A', 'X'))
	end
end
