#!/usr/bin/ruby -w
require 'test/unit'

require 'grammar'

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
		grammar.read_rules(File.open('test.aff'))

		assert_equal('kot', grammar.inflect_noun('kot', :case=>LOCATIVE))
		assert_equal('kot', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'Z'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'A'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE}, 'Z', 'A'))
		assert_equal('kocie', grammar.inflect_noun('kot', {:case=>LOCATIVE, :number=>1}, 'A'))
		assert_equal('kot', grammar.inflect_noun('kot', {:case=>LOCATIVE, :number=>2}, 'A'))

		assert_equal('łobu', grammar.inflect_noun('łob', {:case=>LOCATIVE}, 'A'))
		assert_equal('waltie', grammar.inflect_noun('walt', {:case=>LOCATIVE}, 'X', 'A'))
		assert_equal('waltie', grammar.inflect_noun('walt', {:case=>LOCATIVE}, 'A', 'X'))
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

	def test_adjective
		grammar_text = <<-END
A K 102     y ego y
A K 112,116 0 ch  y
A K 302-303 y ej  y
		END
		grammar = PolishGrammar.new
		grammar.read_rules(grammar_text)

		assert_raise(RuntimeError) { grammar.inflect_adjective('dobry', {:case=>GENITIVE}) }

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
	end

	def test_verb
		grammar_text = <<-END
V a  1 ć m   ać
V a 12 ć cie ać
		END
		grammar = PolishGrammar.new
		grammar.read_rules(grammar_text)

		assert_raise(RuntimeError) { grammar.inflect_verb('foo', {}) } # no forms
		assert_raise(RuntimeError) { grammar.inflect_verb('foo', {:person=>'a'}) } # bad person
		assert_raise(RuntimeError) { grammar.inflect_verb('foo', {:person=>0}) }   # bad person
		assert_raise(RuntimeError) { grammar.inflect_verb('foo', {:person=>-1}) }  # bad person
		assert_raise(RuntimeError) { grammar.inflect_verb('foo', {:person=>4}) }   # bad person
		assert_raise(RuntimeError) { grammar.inflect_verb('foo', {:number=>'a'}) } # bad number
		assert_raise(RuntimeError) { grammar.inflect_verb('foo', {:number=>0}) }   # bad number
		assert_raise(RuntimeError) { grammar.inflect_verb('foo', {:number=>3}) }   # bad number

		assert_equal('latać', grammar.inflect_verb('latać', {:person=>1})) # no inflexion
		assert_equal('latać się', grammar.inflect_verb('latać', {:person=>1}, true))
		assert_equal('latać', grammar.inflect_verb('latać', {:person=>1}, false, 'A'))
		assert_equal('latać się', grammar.inflect_verb('latać', {:person=>1}, true, 'A'))

		assert_equal('latam', grammar.inflect_verb('latać', {:person=>1}, false, 'a'))
		assert_equal('latam', grammar.inflect_verb('latać', {:person=>1, :number=>1}, false, 'a'))
		assert_equal('latać', grammar.inflect_verb('latać', {:person=>1, :number=>2}, false, 'a'))
		assert_equal('latacie', grammar.inflect_verb('latać', {:person=>2, :number=>2}, false, 'a'))
		assert_equal('latam się', grammar.inflect_verb('latać', {:person=>1}, true, 'a'))
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
	end
end
