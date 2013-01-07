#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './dictionary'
require './grammar'

include Grammar

class PolishGrammarTest < Test::Unit::TestCase
	def test_inflexion
		rule3 = Rule.new('t','cie','t','A')
		word = 'kot'
		result = rule3.inflect(word, 'A')
		assert_equal('kot', word)
		assert_equal('kocie', result)
	end

	def test_rule
		rule1 = Rule.new('','a','g','A')
		rule2 = Rule.new('','u','.','A')
		rule3 = Rule.new('t','cie','t','A')
		rule4 = Rule.new('a', 'ie', '[bcnp]a', 'A')
		rule5 = Rule.new('', 'u', '[^bcnp]', 'A')

		assert(!rule1.matches?('bug'))
		assert(!rule1.matches?('bug','a'))
		assert(rule1.matches?('bug','A'))

		assert(!rule2.matches?('bug'))
		assert(!rule2.matches?('bug','a'))
		assert(rule2.matches?('bug','A'))

		assert(!rule3.matches?('bug'))
		assert(rule3.matches?('kot','A'))

		assert_equal('buga', rule1.inflect('bug', 'A'))
		assert_equal('buga', rule1.inflect('bug', 'B', 'A'))
		assert_equal('buga', rule1.inflect('bug', 'A', 'B'))
		assert_equal('bugu', rule2.inflect('bug', 'A'))
		assert_equal('bug', rule3.inflect('bug', 'A'))

		assert_equal('kocie', rule3.inflect('kot', 'A'))

		assert(rule4.matches?('lipa', 'A'))
		assert(!rule4.matches?('lilia', 'A'))
		assert_equal('lipie', rule4.inflect('lipa', 'A'))

		assert(rule5.matches?('bug', 'A'))
		assert(!rule5.matches?('syn', 'A'))
		assert_equal('bugu', rule5.inflect('bug', 'A'))
	end

	def test_noun
		grammar = PolishGrammar.new
		grammar_text = <<-END
N A 6 0 u   b
N A 6 0 ie  t/X
N A 6 t cie t
N A 6 t xxx t
N B 12 a 0 a
		END
		grammar.read_rules grammar_text

		assert_equal('kot', grammar.inflect_noun('kot', :case=>LOCATIVE))
		assert_equal('kot', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'Z'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'A'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'Z', 'A'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE, :number=>1}, 'A'))
		assert_equal('kot', grammar.inflect_noun('kot', {:case=>LOCATIVE, :number=>2}, 'A'))

		assert_equal('łobu', grammar.inflect_noun('łob', {:case=>LOCATIVE}, 'A'))
		assert_equal('waltie', grammar.inflect_noun('walt', {:case=>LOCATIVE}, 'X', 'A'))
		assert_equal('waltie', grammar.inflect_noun('walt', {:case=>LOCATIVE}, 'A', 'X'))

		assert_equal('watah', grammar.inflect_noun('wataha', {:case=>GENITIVE,:number=>2}, 'B'))
	end

	def test_read_rules
		grammar = PolishGrammar.new

		grammar_text = "N a 1 a b c"
		grammar.read_rules(grammar_text)
		assert_equal(1,grammar.size)

		grammar_text = "N b 2 a b c" # make sure that reading clears rules
		grammar.read_rules(grammar_text)
		assert_equal(1,grammar.size)

		grammar_text = "" # test on empty
		grammar.read_rules(grammar_text)
		assert_equal(0,grammar.size)

		grammar_text = "N b 2 a b c # c c" # test inline comments
		grammar.read_rules(grammar_text)
		assert_equal(1,grammar.size)

		grammar_text = <<-END
# starts with a comment
N c 1 a b c
wrong line
A d 1 d d d

N e 1 e e e
N f 1 f f f
		END
		grammar.read_rules(grammar_text)
		assert_equal(4,grammar.size)

		grammar_text = "N a 100,200,300 a b c"
		grammar.read_rules(grammar_text)
		assert_equal(3,grammar.size)

		grammar_text = "N a 100,200,100 a b c"
		grammar.read_rules(grammar_text)
		assert_equal(2,grammar.size)

		grammar_text = "N a 100-110 a b c"
		grammar.read_rules(grammar_text)
		assert_equal(11,grammar.size)

		grammar_text = "N a 100, a b c"
		assert_raise(RuntimeError) { grammar.read_rules(grammar_text) }
		assert_equal(0,grammar.size)

		grammar_text = "N a 100- a b c"
		assert_raise(RuntimeError) { grammar.read_rules(grammar_text) }

		grammar_text = "N a a-b a b c"
		assert_raise(RuntimeError) { grammar.read_rules(grammar_text) }

		grammar_text = "N a 50-1 a b c"
		assert_raise(RuntimeError) { grammar.read_rules(grammar_text) }

		grammar_text = "N a a a b c"
		assert_raise(RuntimeError) { grammar.read_rules(grammar_text) }
	end

	def test_has_rule_for
		grammar = PolishGrammar.new
		grammar.read_rules <<-END
N a 3  ga dze  ga
N a 3  a  e    a
N a 13 ki kom  ki

N b 2 0 a .

N c 2 o a o/1

A a 3 0 emu i
		END
		assert grammar.has_rule_for?(NOUN, 'noga', 'a')
		assert grammar.has_rule_for?(NOUN, 'nuta', 'a')
		assert grammar.has_rule_for?(NOUN, 'foki', 'a')
		assert !grammar.has_rule_for?(NOUN, 'nogi', 'a')
		assert !grammar.has_rule_for?(NOUN, 'noga')
		assert grammar.has_rule_for?(NOUN, 'noga', 'b')
		assert grammar.has_rule_for?(NOUN, 'nog', 'b')
		assert !grammar.has_rule_for?(NOUN, 'jajo', 'c')
		assert grammar.has_rule_for?(NOUN, 'jajo', 'c', '1')
		assert !grammar.has_rule_for?(VERB, 'noga', 'b')
		assert grammar.has_rule_for?(ADJECTIVE, 'głupi', 'a')
	end

	def test_adjective
		grammar_text = <<-END
A K 102     y ego y
A K 104     y ego y
A K 111     y zy  y
A K 112,116 0 ch  y
A K 302-303 y ej  y
A K 211,311 y e   y
		END
		grammar = PolishGrammar.new
		grammar.read_rules(grammar_text)

		assert_raise(GrammarError) { grammar.inflect_adjective('dobry', {:case=>GENITIVE}) }

		assert_equal('dobry', grammar.inflect_adjective('dobry',
			{:gender=>MASCULINE, :number=>1, :case=>NOMINATIVE}, 'K'))
		assert_equal('dobry', grammar.inflect_adjective('dobry',
			{:gender=>MASCULINE, :number=>1, :case=>INSTRUMENTAL}, 'K')) # no rule
		assert_equal('dobrego', grammar.inflect_adjective('dobry',
			{:gender=>MASCULINE, :number=>1, :case=>GENITIVE}, 'K'))
		assert_equal('dobrych', grammar.inflect_adjective('dobry',
			{:gender=>MASCULINE, :number=>2, :case=>GENITIVE}, 'K'))
		assert_equal('dobrych', grammar.inflect_adjective('dobry',
			{:gender=>MASCULINE, :number=>2, :case=>LOCATIVE}, 'K'))
		assert_equal('dobrej', grammar.inflect_adjective('dobry',
			{:gender=>FEMININE, :number=>1, :case=>GENITIVE}, 'K'))
		assert_equal('dobrej', grammar.inflect_adjective('dobry',
			{:gender=>FEMININE, :number=>1, :case=>DATIVE}, 'K'))

		# animate
		assert_equal('dobrego', grammar.inflect_adjective('dobry', # widzę dobrego chłopca
			{:gender=>MASCULINE, :number=>1, :case=>ACCUSATIVE}, 'K'))
		assert_equal('dobry', grammar.inflect_adjective('dobry',   # widzę dobry dzień
			{:gender=>MASCULINE, :number=>1, :case=>ACCUSATIVE, :animate=>false}, 'K'))
		assert_equal('dobrzy', grammar.inflect_adjective('dobry', # dobrzy chłopcy
			{:gender=>MASCULINE, :number=>2, :case=>NOMINATIVE}, 'K'))
		assert_equal('dobre', grammar.inflect_adjective('dobry',   # dobre dni
			{:gender=>MASCULINE, :number=>2, :case=>NOMINATIVE, :animate=>false}, 'K'))
	end

	def test_verb
		grammar_text = <<-END
V a   1 ć m    ać
V a  12 ć cie  ać
V a 102 ć j    ać
V a 112 ć jcie ać
		END
		grammar = PolishGrammar.new
		grammar.read_rules(grammar_text)

		assert_raise(GrammarError) { grammar.inflect_verb('foo', {}) } # no forms
		assert_raise(GrammarError) { grammar.inflect_verb('foo', {:person=>'a'}) } # bad person
		assert_raise(GrammarError) { grammar.inflect_verb('foo', {:person=>0}) }   # bad person
		assert_raise(GrammarError) { grammar.inflect_verb('foo', {:person=>-1}) }  # bad person
		assert_raise(GrammarError) { grammar.inflect_verb('foo', {:person=>4}) }   # bad person
		assert_raise(GrammarError) { grammar.inflect_verb('foo', {:number=>'a'}) } # bad number
		assert_raise(GrammarError) { grammar.inflect_verb('foo', {:number=>0}) }   # bad number
		assert_raise(GrammarError) { grammar.inflect_verb('foo', {:number=>3}) }   # bad number

		assert_equal('latać', grammar.inflect_verb('latać', {:person=>1})) # no inflexion
		assert_equal('latać się', grammar.inflect_verb('latać', {:person=>1}, true))
		assert_equal('latać', grammar.inflect_verb('latać', {:person=>1}, false, 'A'))
		assert_equal('latać się', grammar.inflect_verb('latać', {:person=>1}, true, 'A'))

		assert_equal('latam', grammar.inflect_verb('latać', {:person=>1}, false, 'a'))
		assert_equal('latam', grammar.inflect_verb('latać', {:person=>1, :number=>1}, false, 'a'))
		assert_equal('latać', grammar.inflect_verb('latać', {:person=>1, :number=>2}, false, 'a'))
		assert_equal('latacie', grammar.inflect_verb('latać', {:person=>2, :number=>2}, false, 'a'))
		assert_equal('latam się', grammar.inflect_verb('latać', {:person=>1}, true, 'a'))

		assert_equal('zaczynać', grammar.inflect_verb('zaczynać', {:infinitive=>true}, false, 'a'))
		assert_equal('się zaczynać', grammar.inflect_verb('zaczynać', {:infinitive=>true}, true, 'a'))
		# both infinitive and person
		assert_raise(GrammarError) { grammar.inflect_verb('zaczynać', {:infinitive=>true, :person=>1}, false, 'a') }

		assert_equal 'zaczynaj', grammar.inflect_verb('zaczynać', {:imperative=>true, :person=>2}, false, 'a')
		assert_equal 'zaczynajcie', grammar.inflect_verb('zaczynać', {:imperative=>true, :person=>2, :number=>2}, false, 'a')
		assert_equal 'zaczynaj się', grammar.inflect_verb('zaczynać', {:imperative=>true, :person=>2}, true, 'a')
		# no form
		assert_raise(GrammarError) { grammar.inflect_verb('zaczynać', {:imperative=>true}, false, 'a') }
	end
end

class GenericGrammarTest < Test::Unit::TestCase
	def test_nonlatin_characters
		grammar = GenericGrammar.new
		assert_equal 0, grammar.size
		grammar.read_rules "A a 301 ый ая ый"
		assert_equal 1, grammar.size
	end
end

class GrammarFormTest < Test::Unit::TestCase
	def test_pretty_print
		form = {}
		assert_equal('', GrammarForm.pretty_print(form))

		form = {:gender=>666}
		assert_raise(RuntimeError) { GrammarForm.pretty_print(form) }

		form = {:case=>GENITIVE}
		assert_equal(' D', GrammarForm.pretty_print(form)) # left-padded

		form = {:case=>LOCATIVE, :gender=>NEUTER, :number=>1, :foo=>'bar'}
		assert_equal('n Sg Ms foo=bar', GrammarForm.pretty_print(form))

		form = {:number=>PLURAL, :person=>2}
		assert_equal('Pl 2', GrammarForm.pretty_print(form))

		form = {:infinitive=>1}
		assert_equal('Inf', GrammarForm.pretty_print(form))
	end

	# makes sure that no exceptions are thrown for any legal combination of forms
	def test_all_combinations_legal
		GENDERS.each do |gender|
			gender_form = {:gender=>gender}
			assert_not_nil GrammarForm.pretty_print(gender_form)
			CASES.each do |gram_case|
				case_form = {:case=>gram_case}
				case_gender_form = case_form.merge(gender_form)
				assert_not_nil GrammarForm.pretty_print(case_form)
				assert_not_nil GrammarForm.pretty_print(case_gender_form)
				NUMBERS.each do |number|
					number_form = {:number=>number}
					case_number_form = case_form.merge(number_form)
					full_form = case_number_form.merge(gender_form)
					assert_equal(3, full_form.keys.size)
					assert_not_nil GrammarForm.pretty_print(number_form)
					assert_not_nil GrammarForm.pretty_print(case_number_form)
					assert_not_nil GrammarForm.pretty_print(full_form)
				end
			end
		end

		NUMBERS.each do |number|
			number_form = {:number=>number}
			assert_not_nil GrammarForm.pretty_print(number_form)
			PERSONS.each do |person|
				person_form = {:person=>person}
				number_person_form = number_form.merge(person_form)
				assert_not_nil GrammarForm.pretty_print(person_form)
				assert_not_nil GrammarForm.pretty_print(number_person_form)
			end
		end
	end
end
