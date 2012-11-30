#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './word'
require './test_helper'

include Grammar

class WordTest < Test::Unit::TestCase
	def test_word
		assert_raise(RuntimeError) { Word.new('foo',[],{},-1) }  # wrong freq
		assert_raise(RuntimeError) { Word.new('foo',[1, 2]) } # wrong props, not strings
		assert_raise(ArgumentError) { Word.new() }            # no args
		Word.new('')
		Word.new('foo')
		Word.new('foo',[])
		Word.new('foo',[],{})
		Word.new('foo',[],{},1)
		assert_equal([], Word.new('foo',nil).gram_props)
		Word.new('foo',%w{A B})
		word = Word.new('foo',%w{A B}, {}, 1000)
		assert_equal('foo', word.text)
		assert_equal(['A', 'B'], word.gram_props)
		assert_equal(1000, word.frequency)
	end

	def test_comparison
		def_noun = [%w{A},100,MASCULINE]
		assert_equal(-1, Noun.new('a',*def_noun) <=> Noun.new('b',*def_noun))
		assert_equal(1, Noun.new('b',*def_noun) <=> Noun.new('a',*def_noun))
		assert_equal(0, Noun.new('a',*def_noun) <=> Noun.new('a',*def_noun))
		assert_equal(-1, Noun.new('a',[],100,MASCULINE) <=> Noun.new('a', %w{a},100,MASCULINE))
		assert_equal(1, Noun.new('a', %w{a},100,MASCULINE) <=> Noun.new('a',[],100,MASCULINE))
		assert_equal(0, Noun.new('a', %w{a},100,MASCULINE) <=> Noun.new('a', %w{a},100,MASCULINE))
		assert_equal(-1, Noun.new('a',*def_noun) <=> Verb.new('a',[],100))
		assert_equal(1, Verb.new('a',[],100) <=> Noun.new('a',*def_noun))
		assert_equal(-1, Noun.new('a',%w{a},100,MASCULINE) <=> Verb.new('a',[],100))
		assert_equal(1, Verb.new('a',[],100) <=> Noun.new('a',%w{a},100,MASCULINE))
		assert_not_equal(0, Verb.new('a',[],50,{},false) <=> Verb.new('a',[],100,{},true))
	end

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
		noun = Noun.new('foo',%w{A},100,MASCULINE,{},SINGULAR)
		assert_equal('fooPlFoo', noun.inflect(grammar, {:case=>GENITIVE, :number=>PLURAL}))
		noun = Noun.new('foo',%w{A},100,MASCULINE,{},PLURAL)
		assert_equal('fooPlFoo', noun.inflect(grammar, {:case=>GENITIVE}))

		adjective = Adjective.new('bar',%w{C},100)
		assert_equal('barBar', adjective.inflect(grammar,
			{:case=>GENITIVE,:gender=>MASCULINE}))

		verb = Verb.new('eat',%w{v},100)
		assert_equal('eats', verb.inflect(grammar, {:person=>3}))
	end

	def test_protected_parse
		read_opts = []
		global_opts = {:foo=>'bar'}
		Word.send(:parse,'A FOO(one two) SEMANTIC(good) B',global_opts) do |part|
			read_opts << part
		end
		assert_equal(['A','FOO(one two)','B'], read_opts) # does not include handled by WORD
		assert_equal({:foo=>'bar',:semantic=>['good']}, global_opts)

		global_opts = {}
		Word.send(:parse,'SEMANTIC(good,great) ONLY_WITH(good) NOT_WITH(bad,awful)
		ONLY_WITH_W(angel,saint) NOT_WITH_W(devil,demon)
		TAKES_ONLY(cool) TAKES_NO(boring)
		TAKES_ONLY_W(easy) TAKES_NO_W(old)',global_opts)
		assert_equal({:semantic=>['good','great'],
			:only_with=>['good'],:not_with=>['bad','awful'],
			:only_with_word=>['angel','saint'],:not_with_word=>['devil','demon'],
			:takes_only=>['cool'], :takes_no=>['boring'],
			:takes_only_word=>['easy'], :takes_no_word=>['old']}, global_opts)

		# double semantic
		global_opts = {}
		Word.send(:parse,'SEMANTIC(a) ONLY_WITH(b) NOT_WITH(c) ONLY_WITH_W(d) NOT_WITH_W(e)
		TAKES_ONLY(f) TAKES_NO(g) TAKES_ONLY_W(h) TAKES_NO_W(i)
		SEMANTIC(A) ONLY_WITH(B) NOT_WITH(C) ONLY_WITH_W(D) NOT_WITH_W(E)
		TAKES_ONLY(F) TAKES_NO(G) TAKES_ONLY_W(H) TAKES_NO_W(I)'.gsub(/\s+/,' '),global_opts)
		assert_equal({:semantic=>['a','A'],
			:only_with=>['b','B'],:not_with=>['c','C'],
			:only_with_word=>['d','D'], :not_with_word=>['e','E'],
			:takes_only=>['f','F'], :takes_no=>['g','G'],
			:takes_only_word=>['h','H'], :takes_no_word=>['i','I']}, global_opts)
	end
end

class VerbTest < Test::Unit::TestCase
	def test_parse
		assert_raise(ParseError) { Verb.parse('foo',[],100,"OBJ(na)") } # wrong existing option
		Verb.parse('foo',[],100,"SUBJ") # unknown option - ignore
		assert_raise(ParseError) { Verb.parse('foo',[],100,"OBJ(8)") } # wrong case

		verb = Verb.parse('foo',[],100,"OBJ(3)")
		assert_equal(1,verb.objects.size)
		assert verb.objects[0].is_noun?
		assert !verb.objects[0].is_adjective?
		assert !verb.objects[0].is_infinitive?
		assert_equal(3,verb.objects[0].case)
		assert_nil verb.objects[0].preposition

		verb = Verb.parse('foo',[],100,"OBJ(3) OBJ(o,6)")
		assert_equal(2,verb.objects.size)
		assert verb.objects[0].is_noun?
		assert !verb.objects[0].is_adjective?
		assert !verb.objects[0].is_infinitive?
		assert_equal(3,verb.objects[0].case)
		assert_nil verb.objects[0].preposition
		assert verb.objects[1].is_noun?
		assert !verb.objects[1].is_adjective?
		assert !verb.objects[1].is_infinitive?
		assert_equal(6,verb.objects[1].case)
		assert_equal('o',verb.objects[1].preposition)

		verb = Verb.parse('foo',[],100,"ADJ")
		assert_equal(1,verb.objects.size)
		assert !verb.objects[0].is_noun?
		assert verb.objects[0].is_adjective?
		assert !verb.objects[0].is_infinitive?

		verb = Verb.parse('foo',[],100,"INF")
		assert_equal(1,verb.objects.size)
		assert !verb.objects[0].is_noun?
		assert !verb.objects[0].is_adjective?
		assert verb.objects[0].is_infinitive?
		assert_nil verb.objects[0].preposition

		verb = Verb.parse('foo',[],100,"INF(for)")
		assert_equal(1,verb.objects.size)
		assert !verb.objects[0].is_noun?
		assert !verb.objects[0].is_adjective?
		assert verb.objects[0].is_infinitive?
		assert_equal 'for', verb.objects[0].preposition

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

	def test_suffix
		verb = Verb.parse('mieć',%w{a},100,"SUFFIX(na karku)")
		grammar = PolishGrammar.new
		grammar.read_rules "V a 1 ieć am ieć"
		assert_equal('mieć na karku', verb.inflect(grammar,{:infinitive=>1}))
		assert_equal('mam na karku', verb.inflect(grammar,{:person=>1}))
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
		assert_equal(3, noun.person)
		assert noun.animate # by default

		noun = Noun.parse('foo',[],100,"nan") # not animate
		assert_equal(false, noun.animate)

		noun = Noun.parse('foo',[],100,'PERSON(2)')
		assert_equal(2, noun.person)
		noun = Noun.parse('',[],100,'PERSON(2)')

		assert_raise(ParseError) { Noun.parse('foo',[],100,'PERSON()') }
		assert_raise(ParseError) { Noun.parse('foo',[],100,'PERSON(a)') }
		assert_raise(ParseError) { Noun.parse('foo',[],100,'PERSON(5)') }

		noun = Noun.parse('foo',[],100,'ONLY_SUBJ')
		assert_nil(noun.get_property(:only_obj))
		assert_nil(noun.get_property(:obj_freq))
		assert_not_nil(noun.get_property(:only_subj))

		assert_not_nil(Noun.parse('foo',[],100,'ONLY_OBJ').get_property(:only_obj))
		assert_equal(53, Noun.parse('foo',[],100,'OBJ_FREQ(53)').get_property(:obj_freq))
		assert_raise(ParseError) { Noun.parse('foo',[],100,'OBJ_FREQ') }
		assert_raise(ParseError) { Noun.parse('foo',[],100,'OBJ_FREQ()') }
		assert_raise(ParseError) { Noun.parse('foo',[],100,'OBJ_FREQ(a)') }
	end

	def test_suffix
		noun = Noun.parse('pies',%w{a},100,"SUFFIX(z kulawą nogą)")
		grammar = PolishGrammar.new
		grammar.read_rules "N a 2 ies sa pies"
		assert_equal 'psa z kulawą nogą', noun.inflect(grammar, {:case => 2})
	end

	def test_validation
		noun = Noun.new('bar',[],100,MASCULINE)
		assert_equal(3, noun.person)
		assert_equal(SINGULAR, noun.number)

		noun = Noun.new('bar',[],100,FEMININE,{},PLURAL,2)
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
	include Grammar::TestHelper

	def test_parse
		Adjective.parse('good',[],100,'')
		adjective = Adjective.parse('good',['F'],100,'ONLY_WITH(GOOD)')
		assert_equal 'good', adjective.text
		assert_equal 0, adjective.objects.size
		Adjective.parse('good',[],100,'NOTEXIST')
	end

	def test_parse_object
		adjective = Adjective.parse('good', [], 100, 'ADJ')
		assert_equal 0, adjective.objects.size

		adjective = Adjective.parse('good', [], 100, 'OBJ(z,5)')
		assert_equal 1, adjective.objects.size
		assert_equal 5, adjective.objects[0].case

		# not allowed to have 2 objects
		assert_raise(ParseError) { Adjective.parse('good', [], 100, 'OBJ(z,5) OBJ(od,4)') }
		# wrong case
		assert_raise(ParseError) { Adjective.parse('good', [], 100, 'OBJ(8)') }
	end

	def test_all_forms
		grammar = PolishGrammar.new
		adj = Adjective.new('foo',[],100)
		any = false
		adj.all_forms.each { |form| adj.inflect(grammar,form) ; any = true }
		assert any
	end

	def test_inflect
		grammar = PolishGrammar.new
		grammar.read_rules("A a 104 y ego y")
		adj = Adjective.new('dobry',%w{a},100)

		assert_equal('dobrego', adj.inflect(grammar,{:gender=>MASCULINE, :case=>ACCUSATIVE}))
		assert_equal('dobry', adj.inflect(grammar,{:gender=>MASCULINE, :case=>ACCUSATIVE, :animate=>false}))
		assert_equal('dobrego', adj.inflect(grammar,{:gender=>MASCULINE, :case=>ACCUSATIVE, :animate=>true}))
	end
end

class OtherWordTest < Test::Unit::TestCase
	def test_parse
		word = Other.parse('some other',[],100,'')
		assert_equal 'some other', word.text

		# we don't expect any grammar properties
		assert_raise(ParseError) { Other.parse('some other',['A'],100,'') }
		# we don't expect any properties
		assert_raise(ParseError) { Other.parse('some other',[],100,'word') }
	end
end

class AdverbTest < Test::Unit::TestCase
	def test_parse
		word = Adverb.parse('an adverb',[],100,'')
		assert_equal 'an adverb', word.text
		Adverb.parse('adverb', ['A'],100,'')
		Adverb.parse('adverb', [],100,'ONLY_WITH(GOOD)')
		Adverb.parse('adverb', [],100,'NOTEXIST')
	end
end
