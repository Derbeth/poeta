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
		str = dict.to_s
		assert_equal('Dictionary; 2x adjective, 2x noun', str)
		puts str
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
		END
		dict = Dictionary.new
		dict.read(input)
		assert_equal('Dictionary; 1x adjective, 5x noun, 1x verb', dict.to_s)
		100.times() do
			noun = dict.get_random(NOUN)
			assert_not_equal('nigdy', noun.text)
			assert(%w{jeden dwa}.include?(noun.text), "unexpected noun text: '#{noun.text}'")
			adj = dict.get_random(ADJECTIVE)
			assert_equal('jedyny', adj.text)
			assert_nil(dict.get_random(VERB))
			assert_nil(dict.get_random(ADVERB))
		end
	end
end