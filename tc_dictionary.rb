#!/usr/bin/ruby -w
require 'test/unit'

require 'dictionary'

include Grammar

class DictionaryTest < Test::Unit::TestCase
	def test_word
		assert_raise(RuntimeError) { Word.new('foo',[],-1) }  # wrong freq
		assert_raise(RuntimeError) { Word.new('foo',[1, 2]) } # wrong props, not strings
		assert_raise(ArgumentError) { Word.new() }            # no args
		assert_raise(RuntimeError) { Word.new('') }
		Word.new('foo')
		Word.new('foo',[])
		Word.new('foo',[],1)
		assert_equal([], Word.new('foo',nil).gram_props)
		Word.new('foo',%w{A B})
		word = Word.new('foo',%w{A B}, 1000)
		assert_equal('foo', word.text)
		assert_equal(['A', 'B'], word.gram_props)
		assert_equal(1000, word.frequency)
	end

	def test_read
		input = <<-END
# some test dict
line with not speech part
N 100 słońce/EF
N 100 szatan/G NO_NOUN_NOUN
N 10.5 nietaki
N -1 nieboujemny
 N 10 niebowcięty
N 20 nieboźleodmiana/

Z line with invalid speech part

A 100 zły
A 50 "strasznie mocny"
		END
		dict = Dictionary.new
		dict.read(input)
		assert_equal('Dictionary; 2x adjective, 2x noun', dict.to_s)

		input = ""
		dict.read(input)
		assert_equal('Dictionary', dict.to_s)
	end

	def test_get_random
		srand
		input = <<-END
N 0 nigdy
N 1 jeden
N 0 przenigdy
N 2 dwa
N 0 też nigdy

A 1 jedyny

V 0 nic

O 100 "some other"

D 100 czasem
		END
		dict = Dictionary.new
		dict.read(input)
		assert_equal('Dictionary; 1x adjective, 1x adverb, 5x noun, 1x other, 1x verb', dict.to_s)
		100.times() do
			noun = dict.get_random(NOUN)
			assert_not_equal('nigdy', noun.text)
			assert(%w{jeden dwa}.include?(noun.text), "unexpected noun text: '#{noun.text}'")
			adj = dict.get_random(ADJECTIVE)
			assert_equal('jedyny', adj.text)
			assert_equal('some other',dict.get_random(OTHER).text)
			assert_equal('czasem',dict.get_random(ADVERB).text)
			assert_nil(dict.get_random(VERB))
		end
	end

	def test_parse_verb
		dict = Dictionary.new

		dict_text = "V 100 foo/B"
		dict.read(dict_text)
		verb = dict.get_random(VERB)
		assert_equal('foo', verb.text)
		assert_equal(%w{B}, verb.gram_props)
		assert !verb.reflexive
		assert_nil verb.preposition
		assert_nil verb.object_case

		dict_text = "V 100 foo OBJ(,,,)\nV 100 bar REFLEX"
		dict.read(dict_text)
		assert_equal('Dictionary; 1x verb', dict.to_s)
		verb = dict.get_random(VERB)
		assert_equal('bar', verb.text)
		assert_equal([], verb.gram_props)
		assert verb.reflexive
		assert_nil verb.preposition
		assert_nil verb.object_case

		dict_text = "V 100 foo/B OBJ(4)"
		dict.read(dict_text)
		verb = dict.get_random(VERB)
		assert_equal(%w{B}, verb.gram_props)
		assert !verb.reflexive
		assert_nil verb.preposition
		assert_equal(4, verb.object_case)

		dict_text = "V 100 foo OBJ(4,na)"
		dict.read(dict_text)
		assert_equal('Dictionary', dict.to_s) # no words, parse error

		dict_text = "V 100 foo OBJ(8)"
		dict.read(dict_text)
		assert_equal('Dictionary', dict.to_s) # no words, wrong case

		dict_text = "V 100 foo OBJ(na)"
		dict.read(dict_text)
		assert_equal('Dictionary', dict.to_s) # no words, parse error

		dict_text = "V 100 foo/B OBJ(na,4) REFLEX"
		dict.read(dict_text)
		verb = dict.get_random(VERB)
		assert verb.reflexive
		assert_equal('na', verb.preposition)
		assert_equal(4, verb.object_case)
	end

	def test_inline_comments
		dict = Dictionary.new
		dict.read("V 100 foo # REFLEX")
		verb = dict.get_random(VERB)
		assert !verb.reflexive
	end
end

class WordTest < Test::Unit::TestCase
	def test_inflect
		grammar_text = <<-END
N A   2 0 Foo .
N B   2 0 Wrong .
N A  12 0 PlFoo .
N B  12 0 WrongPlFoo .
A C 102 0 Bar .
A D 102 0 TooWrong .
V v   3 0 s .
V w   3 0 AlsoWrong .
		END
		grammar = PolishGrammar.new
		grammar.read_rules(grammar_text)

		noun = Noun.new('foo',%w{A},100,MASCULINE)
		assert_equal('fooFoo', noun.inflect(grammar, {:case=>GENITIVE}))
		noun = Noun.new('foo',%w{A},100,MASCULINE,SINGULAR)
		assert_equal('fooPlFoo', noun.inflect(grammar, {:case=>GENITIVE, :number=>PLURAL}))
		noun = Noun.new('foo',%w{A},100,MASCULINE,PLURAL)
		assert_equal('fooPlFoo', noun.inflect(grammar, {:case=>GENITIVE}))

		adjective = Adjective.new('bar',%w{C},100)
		assert_equal('barBar', adjective.inflect(grammar,
			{:case=>GENITIVE,:gender=>MASCULINE}))

		verb = Verb.new('eat',%w{v},100)
		assert_equal('eats', verb.inflect(grammar, {:person=>3}))
	end
end

class VerbTest < Test::Unit::TestCase
	def test_parse
		assert_raise(ParseError) { Verb.parse('foo',[],100,"OBJ(na)") } # wrong existing option
		Verb.parse('foo',[],100,"SUBJ") # unknown option - ignore
		assert_raise(ParseError) { Verb.parse('foo',[],100,"OBJ(8)") } # wrong case
		verb = Verb.parse('foo',[],100,"OBJ(3)")
		assert_equal(3,verb.object_case)
		verb = Verb.parse('foo',[],100,"REFL")
		assert verb.reflexive
		verb = Verb.parse('foo',[],100,"REFLEX")
		assert verb.reflexive
		verb = Verb.parse('foo',[],100,"REFLEXIVE")
		assert verb.reflexive
	end

	def test_all_forms
		grammar = PolishGrammar.new
		verb = Verb.new('foo',[],100)
		any = false
		verb.all_forms.each { |form| verb.inflect(grammar,form) ; any = true }
		assert any
	end
end

class NounTest < Test::Unit::TestCase
	def test_parse
		noun = Noun.parse('foo',[],100,"NOTEXIST") # unknown option - ignore
		assert_equal(MASCULINE, noun.gender)
		assert_equal(1, noun.number)
		noun = Noun.parse('foo',[],100,"f Pl")
		assert_equal(FEMININE, noun.gender)
		assert_equal(2, noun.number)
		noun = Noun.parse('foo',[],100,"Pl n")
		assert_equal(NEUTER, noun.gender)
		assert_equal(2, noun.number)
	end

	def test_validation
		noun = Noun.new('bar',[],100,MASCULINE)
		assert_equal(3, noun.person)
		assert_equal(SINGULAR, noun.number)

		noun = Noun.new('bar',[],100,FEMININE,PLURAL,2)
		assert_equal(2,noun.person)
		assert_equal(PLURAL,noun.number)

		assert_raise(RuntimeError) { Noun.new('bar',[],100,FEMININE,PLURAL,5) }
	end

	def test_all_forms
		grammar = PolishGrammar.new
		noun = Noun.new('foo',[],100,MASCULINE)
		any = false
		noun.all_forms.each { |form| noun.inflect(grammar,form) ; any = true }
		assert any
	end
end

class AdjectiveTest < Test::Unit::TestCase
	def test_all_forms
		grammar = PolishGrammar.new
		adj = Adjective.new('foo',[],100)
		any = false
		adj.all_forms.each { |form| adj.inflect(grammar,form) ; any = true }
		assert any
	end
end

class OtherWordTest < Test::Unit::TestCase
	def test_parse
		word = Other.parse('some other',[],100,'')
		assert_equal 'some other', word.text

		assert_raise(ParseError) { Other.parse('some other',['A'],100,'') }
		assert_raise(ParseError) { Other.parse('some other',[],100,'word') }
	end
end

class AdverbTest < Test::Unit::TestCase
	def test_parse
		word = Adverb.parse('an adverb',[],100,'')
		assert_equal 'an adverb', word.text
	end
end

class SmartRandomDictionaryTest < Test::Unit::TestCase
	def test_correct
		dictionary_text = "N 1 foo\nN 1 bar"
		sum_freqs = 2
		dictionary = Dictionary.new
		smart_dictionary = SmartRandomDictionary.new(1)
		dictionary.read(dictionary_text)
		smart_dictionary.read(dictionary_text)
		srand 1
		assert_equal(1,rand(sum_freqs))
		assert_equal(1,rand(sum_freqs))
		assert_equal(0,rand(sum_freqs))
		100.times do
			srand 1
			assert_equal('bar', dictionary.get_random(NOUN).text)
			assert_equal('bar', dictionary.get_random(NOUN).text)
			srand 1
			assert_equal('bar', smart_dictionary.get_random(NOUN).text)
			assert_equal('foo', smart_dictionary.get_random(NOUN).text)
		end
	end
end
