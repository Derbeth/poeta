#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './sentence'

include Grammar

class StringTest < Test::Unit::TestCase
	def test_ljust
		assert_equal("foo   ", "foo".ljust(6))
		assert_equal("foo   ", "foo".fixed_ljust(6))
		assert_equal("foó   ", "foó".fixed_ljust(6))
		assert_equal("góo   ", "góo".fixed_ljust(6))
		assert_equal("hóó   ", "hóó".fixed_ljust(6))
	end
end

class SentenceTest < Test::Unit::TestCase

	# wrapper for Sentence only setting some default options
	class SentenceWrapper < Sentence
		def initialize(*args)
			super(*args)
			self.object_adj_chance = 0
			self.double_noun_chance = 0
		end
	end

	def setup
		srand
	end

	def test_trim
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		sentence = SentenceWrapper.new(dictionary,grammar,'')
		assert_equal('', sentence.write)
		sentence = SentenceWrapper.new(dictionary,grammar,'  ')
		assert_equal('', sentence.write)
		sentence = SentenceWrapper.new(dictionary,grammar,' ${VERB} ${SUBJ}   ${SUBJ} ')
		assert_equal('foo foo', sentence.write)

		assert_equal('foo?', SentenceWrapper.new(dictionary, grammar, '${NOUN} ${VERB}?').write)
		assert_equal('foo.', SentenceWrapper.new(dictionary, grammar, '${NOUN} ${VERB}.').write)
	end

	def test_write
		pattern = '${NOUN}'
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		dictionary.read('N 100 foo')
		sentence = SentenceWrapper.new(dictionary,grammar,pattern)
		assert_equal('${NOUN}', sentence.pattern)
		sentence.write
		assert_equal('${NOUN}', sentence.pattern)
	end

	def test_handle_subject
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		sentence = SentenceWrapper.new(dictionary,grammar,'a ${SUBJ} b')
		text = sentence.write
		assert_equal('a foo b', text)
		assert_equal('foo', sentence.subject.text)

		contr_dict = ControlledDictionary.new
		contr_dict.read "N 100 foo\nN 100 bar"
		contr_dict.set_indices NOUN, [0, 1]
		sentence = SentenceWrapper.new(contr_dict,grammar,'a ${SUBJ} ${SUBJ2} b')
		text = sentence.write
		assert_equal('a foo bar b', text)
		assert_equal('foo', sentence.subject.text)
	end

	def test_handle_noun
		dictionary = Dictionary.new
		grammar = PolishGrammar.new

		dictionary.read("N 100 pora/a")
		grammar.read_rules("N a 6 a ze ra")
		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN(6)}')
		assert_equal('porze', sentence.write)

		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ(6)}')
		assert_equal('porze', sentence.write)
	end

	def test_handle_adjective
		dictionary_text = "N 100 stuff\nA 100 cool"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		sentence = SentenceWrapper.new(dictionary,grammar,'?${ADJ} ${NOUN}?')
		assert_equal('?cool stuff?', sentence.write)

		dictionary = ControlledDictionary.new
		dictionary.read "N 100 stuff\nN 100 things\nA 100 cool\nA 100 bad"

		dictionary.set_indices NOUN, [0, 1]
		dictionary.set_indices ADJECTIVE, [0, 1]
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ1} ${NOUN} ${ADJ2} ${NOUN2}')
		assert_equal 'cool stuff bad things', sentence.write
		dictionary.set_indices NOUN, [1, 0]
		dictionary.set_indices ADJECTIVE, [1, 1]
		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN1} ${ADJ1} ${NOUN2} ${ADJ1}')
		assert_equal('things bad stuff bad', sentence.write)

		dictionary.read("N 100 psy n Pl\nA 100 zły/a")
		grammar.read_rules("A a 211 y e y")
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${NOUN}')
		assert_equal('złe psy', sentence.write)

		dictionary.read("N 100 pory f\nA 100 dobry/a")
		grammar.read_rules("A a 302 y ej y")
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ(2)} ${NOUN}')
		assert_equal('dobrej pory', sentence.write)

		dictionary.read("N 100 pory f\nA 100 dobry/a")
		grammar.read_rules("A a 311 y e y")
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ(11)} ${NOUN}')
		assert_equal('dobre pory', sentence.write)

		# two adjectives to one noun
		dictionary.read "N 100 pora f\nA 100 dobry/a\nA 100 prosty/a"
		dictionary.set_indices ADJECTIVE, [1, 0]
		grammar.read_rules("A a 301 y a y")
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${ADJ} ${NOUN}')
		assert_equal('prosta dobra pora', sentence.write)

		dictionary.read "N 100 pora f\nA 100 dobry/a\nA 100 prosty/a"
		dictionary.set_indices ADJECTIVE, [1, 0]
		grammar.read_rules("A a 301 y a y")
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${ADJ} ${SUBJ}')
		assert_equal('prosta dobra pora', sentence.write)

		# adjective with an object
		dictionary.read "N 100 kibic m\nN 100 szczęście/a f\nA 100 pijany/a ATTR(z,2)"
		dictionary.set_indices NOUN, [0, 1]
		grammar.read_rules("N a 2 e a e")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${ADJ}')
		assert_equal('kibic pijany ze szczęścia', sentence.write)
	end

	def test_double_adjective
		grammar = GenericGrammar.new
		# to check if form is passed
		grammar.read_rules "A a 301 0 e ."
		dictionary = Dictionary.new
		dictionary.read "N 100 Stube f\nA 100 dies/a DOUBLE\nA 100 dein/a POSS\nA 10 klein/a\n"

		possible = ['diese kleine Stube', 'deine kleine Stube', 'kleine Stube']
		# times to check if there is an infinite loop
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${NOUN}')
			assert_raise(ArgumentError) { sentence.double_adj_chance = 100 }
			sentence.double_adj_chance = 1
			assert_includes possible, sentence.write
		end
	end

	def test_handle_no_adjective
		dictionary_text = "N 100 nobody\nA 100 cool"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = GenericGrammar.new

		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${NOUN}')
		assert_equal('cool nobody', sentence.write)

		dictionary_text = "N 100 nobody NO_ADJ\nA 100 cool"
		dictionary.read(dictionary_text)

		assert_equal('nobody', sentence.write)
	end

	def test_handle_animate_inanimate
		dictionary = Dictionary.new
		grammar = PolishGrammar.new
		grammar.read_rules("A a 104 y ego y")
		dictionary.read("A 100 dobry/a\nN 100 czas m nan")
		sentence = SentenceWrapper.new(dictionary,grammar,'widzę ${ADJ(4)} ${NOUN(4)}')
		assert_equal('widzę dobry czas', sentence.write)

		dictionary.read("A 100 dobry/a\nN 100 psa m")
		sentence = SentenceWrapper.new(dictionary,grammar,'widzę ${ADJ(4)} ${NOUN(4)}')
		assert_equal('widzę dobrego psa', sentence.write)
	end

	def test_handle_noun_attribute
		dictionary = Dictionary.new
		grammar = GenericGrammar.new
		grammar.read_rules "N a 2 0 a .\nN a 3 0. owi ."
		dictionary.read "N 10 bat/a\nN 10 tag/a ATTR(z,2)\nN 10 log/a\nV 10 oddaje OBJ(3)\n"

		# tag should always come with an attribute
		possible = ['bat', 'tag z bata', 'tag z loga', 'log']
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN}')
			assert_includes possible, sentence.write
		end

		possible = ['bat oddaje logowi', 'bat oddaje tagowi z loga',
			'tag z bata oddaje logowi', 'tag z loga oddaje batowi',
			'tag z bata oddaje batowi', # clumsy repetition here, but let other tests take care of it
			'log oddaje batowi', 'log oddaje tagowi z bata',
		]
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
			assert_includes possible, sentence.write
		end

		# now test subject
		dictionary.read "N 10 bat/a ONLY_OBJ\nN 10 tag/a ATTR(z,2)\nN 10 log/a ONLY_OBJ\nV 10 oddaje\n"

		possible = ['tag z bata oddaje', 'tag z loga oddaje']
		5.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB}')
			assert_includes possible, sentence.write
		end
	end

	# objects marked as ONLY_SUBJ should not be taken as noun attributes
	def test_noun_attribute_respects_subj_only
		dictionary = Dictionary.new
		grammar = GenericGrammar.new
		dictionary.read "N 30 foo ATTR(prep,2)\nN 10 bar ATTR(prep,3)\nN 10 baz\nN 50 forbidden1 ONLY_SUBJ\nN 50 forbidden2 ONLY_SUBJ\n"

		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'oto ${NOUN}')
			assert_match(/oto \w+/, sentence.write)
			assert_no_match(/prep forbidden[12]/, sentence.write)
		end
	end

	# when wrongly used, noun attributes could cause infinite loops
	def test_noun_attribute_inf_loop
		dictionary = Dictionary.new
		grammar = GenericGrammar.new
		dictionary.read "N 10 foo ATTR(prep,2)\nN 10 bar ATTR(prep,3)\nN 10 baz ATTR(prep,4)\n"

		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'oto ${NOUN}')
			assert_match(/oto \w+/, sentence.write)
		end
	end

	def test_noun_attribute_forbidden_combinations
		dictionary = Dictionary.new
		grammar = GenericGrammar.new
		dictionary.read "N 10 licence ATTR(to,2)\nN 10 kill\nN 10 we Pl PERSON(1)"

		possible = ['this licence to kill', 'this kill', 'this we']
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'this ${NOUN}')
			assert_includes(possible, sentence.write)
		end
	end

	def test_handle_double_usage
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		dictionary_text = <<-END
N 100 "foo"
N 100 "bar"
N 100 "baz"

V 100 goes OBJ(1)
V 100 runs OBJ(1)
V 100 kills OBJ(1)
		END
		dictionary.read(dictionary_text)
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB}, ${SUBJ} ${VERB}')

		10.times do
			text = sentence.write
			parts = text.split(/, /)
			assert_equal(parts[0], parts[1], "sentence: #{text}")
		end

	end

	def test_handle_semantic
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		dictionary.read("N 100 work SEMANTIC(GOOD)\nA 100 good ONLY_WITH(GOOD)\n")
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${NOUN}')
		assert_equal('good work', sentence.write)
		dictionary.read("N 100 work\nA 100 good ONLY_WITH_W(work)\n")
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${NOUN}')
		assert_equal('good work', sentence.write)

		# noun -> adjective
		dictionary.read("N 100 work SEMANTIC(GOOD)\nA 100 good\nA 100 bad NOT_WITH(GOOD)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${SUBJ}')
			assert_equal('good work', sentence.write)
		end
		dictionary.read("N 100 work\nA 100 good\nA 100 bad NOT_WITH_W(work)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${SUBJ}')
			assert_equal('good work', sentence.write)
		end

		dictionary.read("N 100 work SEMANTIC(GOOD)\nA 100 good NOT_WITH(BAD)\n")
		sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${SUBJ}')
		assert_equal('good work', sentence.write)

		dictionary.read("N 100 work SEMANTIC(GOOD)\nA 100 good\nA 100 bad ONLY_WITH(BAD)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${NOUN}')
			assert_equal('good work', sentence.write)
		end
		dictionary.read("N 100 work\nA 100 good\nA 100 bad ONLY_WITH_W(idea)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${NOUN}')
			assert_equal('good work', sentence.write)
		end

		# verb -> noun object
		dictionary.read("V 100 purge OBJ(1) TAKES_ONLY(EVIL)\nN 100 evil SEMANTIC(EVIL)\nN 100 good SEMANTIC(GOOD)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('purge evil', sentence.write)
		end
		dictionary.read("V 100 purge OBJ(1) TAKES_ONLY(EVIL,HIPEREVIL)\nN 100 evil SEMANTIC(ADJECTIVE,EVIL)\nN 100 good SEMANTIC(GOOD,ADJECTIVE)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('purge evil', sentence.write)
		end
		dictionary.read("V 100 purge OBJ(1) TAKES_NO(GOOD)\nN 100 evil SEMANTIC(EVIL)\nN 100 good SEMANTIC(GOOD)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('purge evil', sentence.write)
		end
		dictionary.read("V 100 purge OBJ(1) TAKES_NO(GOOD,HIPERGOOD)\nN 100 evil SEMANTIC(ADJECTIVE,EVIL)\nN 100 good SEMANTIC(GOOD,ADJECTIVE)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('purge evil', sentence.write)
		end

		dictionary.read("V 100 spread OBJ(1) TAKES_ONLY_W(good)\nN 100 evil\nN 100 good")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('spread good', sentence.write)
		end
		dictionary.read("V 100 spread OBJ(1) TAKES_NO_W(evil)\nN 100 evil\nN 100 good")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('spread good', sentence.write)
		end

		# verb -> verb object
		srand 2
		dictionary.read("V 1000 muszę INF\nV 100 chcieć\nV 30 lecieć") # no semantic - expect wrong result
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_equal('muszę chcieć', sentence.write)
		srand 2
		dictionary.read("V 1000 muszę INF TAKES_NO(MODAL)\nV 100 chcieć SEMANTIC(MODAL)\nV 30 lecieć SEMANTIC(MOVE)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_equal('muszę lecieć', sentence.write)

		# subject -> verb
		srand 2
		dictionary.read("N 100 policja\nV 100 rymuje\nV 10 idzie") # no semantic - expect wrong result
		sentence = SentenceWrapper.new(dictionary, grammar, '${SUBJ} ${VERB}');
		assert_equal('policja rymuje', sentence.write)
		srand 2
		dictionary.read("N 100 policja SEMANTIC(NOT_COOL)\nV 100 rymuje NOT_WITH(NOT_COOL)\nV 10 idzie")
		sentence = SentenceWrapper.new(dictionary, grammar, '${SUBJ} ${VERB}');
		assert_equal('policja idzie', sentence.write)

		dictionary.read("N 100 ziomy\nN 100 policja SEMANTIC(POLICJA)\nV 100 idziesz\nV 100 donosisz NOT_WITH(ZIOM)")
		10.times do
			sentence = SentenceWrapper.new(dictionary, grammar, 'spoko jak ${SUBJ(TAKES_NO POLICJA)}')
			assert_equal('spoko jak ziomy', sentence.write)
			sentence = SentenceWrapper.new(dictionary, grammar, 'spoko jak ${SUBJ(IG_ONLY,TAKES_NO POLICJA)}')
			assert_equal('spoko jak ziomy', sentence.write)
			sentence = SentenceWrapper.new(dictionary, grammar, 'spoko jak ${NOUN(TAKES_NO POLICJA)}')
			assert_equal('spoko jak ziomy', sentence.write)
			sentence = SentenceWrapper.new(dictionary, grammar, '${VERB(2,SEMANTIC ZIOM)}')
			assert_equal('idziesz', sentence.write)
		end
	end

	def test_handle_verb
		dictionary = Dictionary.new
		dictionary.read("N 100 lipy f Pl\nV 100 rosnąć/a")
		grammar = PolishGrammar.new
		grammar.read_rules("V a 13 ć 0 ć")

		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB}')
		assert_equal('lipy rosną', sentence.write)
		
		dictionary.read("N 100 lipy f Pl\nV 100 rosnąć/a REFLEXIVE")
		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB}')
		assert_equal('lipy rosną się', sentence.write)

		dictionary.read("V 100 rosnąć/a")
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(13)}')
		assert_equal('rosną', sentence.write)

		dictionary.read("N 100 lipa f\nV 100 rosnąć/a")
		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN}. ${VERB2(13)}')
		assert_equal('lipa. rosną', sentence.write)

		dictionary.read("V 100 rosnąć/a")
		grammar.read_rules("V a 1 ąć ę ąć")
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)}')
		assert_equal('rosnę', sentence.write)

		dictionary.read("V 100 rosnąć/a SUFFIX(w siłę)")
		grammar.read_rules("V a 1 ąć ę ąć")
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)}')
		assert_equal('rosnę w siłę', sentence.write)

		dictionary.read("N 100 lipa/b f\nV 100 uderzać/a OBJ(4)")
		grammar.read_rules("N b 4 a ę a\nV a 1 ć m ć")
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_equal('uderzam lipę', sentence.write)
		sentence = SentenceWrapper.new(dictionary,grammar,'trzeba ${VERB(INF)} ${OBJ}')
		assert_equal('trzeba uderzać lipę', sentence.write)
	end

	def test_handle_object
		dictionary = Dictionary.new
		dictionary.read("N 100 pies\nN 100 kot/a\nV 100 je")
		srand 1
		assert_equal 'pies', dictionary.get_random(NOUN).text

		grammar = PolishGrammar.new
		grammar.read_rules("N a 2,4 0 a .\nN a 15 0 ami .\nN b 3 ies su ies\nA a 102,104 y ego y")

		srand 1
		# verb has no object set
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${OBJ} ${VERB}')
		assert_equal('pies je', sentence.write)

		srand 1
		dictionary.read("N 100 pies\nN 100 kot/a\nV 100 je OBJ(4)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies je kota', sentence.write)

		srand 1
		# noun suffix
		dictionary.read("N 100 pies\nN 100 kot/a SUFFIX(w butach)\nV 100 je OBJ(4)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies je kota w butach', sentence.write)

		srand 1
		# object preposition
		dictionary.read("N 100 pies\nN 100 kot/a Pl\nV 100 goni OBJ(za,5)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies goni za kotami', sentence.write)

		srand 8
		# handle two objects of a noun
		dictionary.read "N 100 pies/b\nN 100 kot/a\nV 100 daję OBJ(3) OBJ(4)"
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_equal 'daję psu kota', sentence.write

		srand
		# object adjective
		dictionary.read "N 100 kot/a \nA 100 ładny/a \nV 100 widzę OBJ(4)"
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_raise(ArgumentError) { sentence.object_adj_chance = 100 }
		sentence.object_adj_chance = 1
		assert_equal 'widzę ładnego kota', sentence.write

		srand
		# adjective for noun attribute, additionally check proper preposition letter change
		dictionary.read "N 10 wąsy ATTR(w,4)\nN 10 kot/a ONLY_OBJ\nA 10 wredny/a"
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ}')
		sentence.object_adj_chance = 1
		assert_equal 'wąsy we wrednego kota', sentence.write

		dictionary.read "N 10 wąsy ATTR(w,4)\nN 10 wrot/a ONLY_OBJ\nA 10 ładny/a"
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ}')
		sentence.object_adj_chance = 1
		# without the adjective should be 'wąsy we wrota'
		assert_equal 'wąsy w ładnego wrota', sentence.write
	end

	def test_object_wont_equal_subject
		dictionary = Dictionary.new
		dictionary.read("N 100 pies\nN 30 kota/a\nV 100 goni OBJ(4)")
		srand 2
		assert_equal('pies', dictionary.get_random_subject.text)
		assert_equal('pies', dictionary.get_random_object.text)
		srand 2
		grammar = PolishGrammar.new
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies goni kota', sentence.write)
	end
	
	def test_two_objects_and_subject_different
		grammar = GenericGrammar.new
		dictionary = Dictionary.new
		dictionary.read "N 100 Alice\nN 100 Bob\nN 100 Chris\nN 100 Donald\nV 100 gives OBJ(2) OBJ(2)"
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
			text = sentence.write
			assert_match(/^\w+ \w+ \w+ \w+$/, text, "Failed to resolve subject, verb and two subjects: '#{text}'")
			%w{Alice Bob Chris Donald}.each do |noun|
				assert_no_match(/#{noun}.*#{noun}/, text, "Duplicated #{noun} in '#{text}'")
			end
		end
	end

	def test_object_preposition_letter_change
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		srand 1
		dictionary.read("N 100 pies\nN 30 zebrą\nV 100 idzie OBJ(z,5)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie z zebrą', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 zdradą\nV 100 idzie OBJ(z,5)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie ze zdradą', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 szkołą\nV 100 idzie OBJ(z,5)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie ze szkołą', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 szansą\nV 100 idzie OBJ(z,5)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie z szansą', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 skrętem\nV 100 idzie OBJ(z,5)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie ze skrętem', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 wstydem\nV 100 idzie OBJ(z,5)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie ze wstydem', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 walce\nV 100 idzie OBJ(w,6)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie w walce', sentence.write)
		dictionary.read("N 100 pies\nN 30 wronie\nV 100 idzie OBJ(w,6)")
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie we wronie', sentence.write)

		srand 1
		dictionary.read "N 100 pies \nN 30 mnicha \nV 100 idzie OBJ(od,6)"
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal 'pies idzie od mnicha', sentence.write
		srand 1
		dictionary.read "N 100 pies \nN 30 mnie \nV 100 idzie OBJ(od,6)"
		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal 'pies idzie ode mnie', sentence.write
	end

	def test_double_noun_polish
		grammar = PolishGrammar.new
		grammar.read_rules <<-END
N a   2 0 a   .
N a   5 0 em  .
N b   2 0 u   .
N b  12 0 ów  .
N b   5 0 em  .
A y 101 0 y   .
A y 105 0 ym  .
A y 111 0 e   .
A y 115 0 ymi .
		END
		dictionary = ControlledDictionary.new
		dictionary.read "N 100 zwierz/a \nN 100 las/b ONLY_OBJ \nV 100 idzie OBJ(z,5)\nA 100 czarn/y"

		assert_raise(ArgumentError) { Sentence.new(dictionary,grammar,'${NOUN}').double_noun_chance = 100 }

		# additionally check that preposition letter change catches the correct noun
		5.times do
			sentence = Sentence.new(dictionary,grammar,'${VERB(3)} ${OBJ}')
			sentence.double_noun_chance = 1
			sentence.object_adj_chance = 0
			dictionary.set_indices NOUN, [0, 1] # zwierz, las
			assert_equal 'idzie ze zwierzem lasu', sentence.write
			dictionary.set_indices NOUN, [] # make random again

			sentence = Sentence.new(dictionary,grammar,'${VERB(3)} ${OBJ}')
			sentence.double_noun_chance = 1
			sentence.object_adj_chance = 1
			dictionary.set_indices NOUN, [0, 1] # zwierz, las
			assert_equal 'idzie z czarnym zwierzem lasu', sentence.write
		end

		# additionally check that verb uses number from the first noun, even
		# if the second noun is plural
		dictionary.read "N 100 zwierz/a \nN 100 las/b Pl ONLY_OBJ \nV 100 idzie\nA 100 czarn/y"
		5.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${ADJ} ${SUBJ} ${VERB}')
			sentence.double_noun_chance = 1
			dictionary.set_indices NOUN, [0, 1] # zwierz, las
			assert_equal 'czarny zwierz lasów idzie', sentence.write
		end
	end

	def test_double_noun_english
		grammar = EnglishGrammar.new
		dictionary = ControlledDictionary.new
		dictionary.read "N 100 eye\nN 100 eagle"
		5.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ}')
			sentence.double_noun_chance = 1
			dictionary.set_indices NOUN, [0, 1]
			assert_equal 'eye of eagle', sentence.write
		end
	end

	def test_double_noun_forbidden_combinations
		grammar = EnglishGrammar.new
		dictionary = Dictionary.new
		dictionary.read "N 100 eye\nN 100 eagle\nN 100 I PERSON(1)"
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ}')
			sentence.double_noun_chance = 1
			text = sentence.write
			assert_match(/\w+/, text)
			assert_no_match(/\b(of I|I of)\b/, text)
		end

		dictionary.read "N 100 eagle\nN 100 I PERSON(1)"
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ}')
			sentence.double_noun_chance = 1
			text = sentence.write
			assert_includes ['eagle', 'I'], text
		end
	end

	def test_double_noun_infinite_loop
		grammar = GenericGrammar.new
		dictionary = Dictionary.new
		dictionary.read "N 10 bat\nN 10 blog ATTR(2)\nN 10 log ATTR(z,2)\nN 10 tag ATTR(2)\nV 10 widzi OBJ(2)"
		5.times do
			sentence = Sentence.new(dictionary,grammar,'${NOUN}')
			sentence.double_noun_chance = 0.5
			assert_match(/\w+/, sentence.write)

			sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
			sentence.double_noun_chance = 0.5
			assert_match(/\w+ \w+ \w+/, sentence.write)
		end
	end

	def test_handle_infinitive_object
		dictionary = Dictionary.new
		dictionary.read("N 100 pies\nV 100 chce INF\nV 30 jeść")
		srand 1
		assert_equal('chce', dictionary.get_random(VERB).text)
		assert_equal('chce', dictionary.get_random(VERB).text)

		srand 1
		grammar = PolishGrammar.new
		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
		assert_equal('pies chce jeść', sentence.write)

		# check that ONLY_OBJ works for verbs
		srand
		dictionary.read "N 100 pies\nV 100 chce INF\nV 30 jeść ONLY_OBJ"
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
			assert_equal 'pies chce jeść', sentence.write
		end

		# infinitive taking object itself
		srand 1
		grammar.read_rules "N a 4 ies sa ies\nV a 1 e ę e\n"
		dictionary.read "N 100 pies/a\nV 100 chce/a INF\nV 30 jeść OBJ(4)"
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_equal 'chcę jeść psa', sentence.write

		srand 1
		dictionary.read("N 100 pies\nV 100 chce INF\nV 30 przejść REFL")
		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
		assert_equal('pies chce się przejść', sentence.write)

		# infitinive with preposition
		srand 1
		dictionary.read "N 100 they\nV 100 want INF(to)\nV 30 eat"
		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
		assert_equal('they want to eat', sentence.write)
	end

	def test_handle_adjective_object
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		dictionary.read("N 100 flower\nV 100 is ADJ\nA 100 beautiful")

		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
		assert_equal('flower is beautiful', sentence.write)

		dictionary.read("N 100 flower\nV 100 is ADJ TAKES_NO(BAD)\nA 100 beautiful SEMANTIC(GOOD)\nA 100 ugly SEMANTIC(BAD)")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
			assert_equal('flower is beautiful', sentence.write)
		end

		# what if we implicitly set noun
		dictionary.read("V 100 jesteśmy ADJ\nA 100 dobry/a")
		grammar.read_rules("A a 111 y zy y")
		sentence = SentenceWrapper.new(dictionary,grammar,'${VERB(11)} ${OBJ}')
		assert_equal('jesteśmy dobrzy', sentence.write)
	end

	def test_handle_adjective_object_not_as_object
		grammar = GenericGrammar.new
		dictionary = Dictionary.new
		# adjective 'this' should never be chosen as object for 'is' because 'this' is marked as NOT_AS_OBJ
		dictionary.read("N 100 flower\nV 100 is ADJ\nA 10 beautiful\nA 100 this NOT_AS_OBJ")
		10.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
			assert_equal('flower is beautiful', sentence.write)
		end
	end
	
	# verb requires an object but sentence pattern explicitly omits object
	# sentence should be written without object
	def test_no_object_verb_object
		grammar = GenericGrammar.new
		dictionary = Dictionary.new
		dictionary.read("N 100 people \nV 100 become ADJ \nA 100 sick\n")

		sentence = SentenceWrapper.new(dictionary,grammar,'what ${SUBJ} ${VERB}')
		assert_equal('what people become', sentence.write)
	end

	def test_handle_other
		dictionary = Dictionary.new
		dictionary.read('O 100 "some other"')

		srand 7
		draw = rand
		sentence = SentenceWrapper.new(dictionary,'grammar','')
		default_other_choice = sentence.other_word_chance
		assert draw < default_other_choice && draw < 0.5, "got #{draw} >= #{default_other_choice}"
		srand 3
		draw = rand
		assert draw > 0.5, "got #{draw}"

		srand 3
		sentence = SentenceWrapper.new(dictionary,'grammar','${OTHER}')
		sentence.other_word_chance = 0.5
		assert_equal('', sentence.write)

		srand 7
		sentence = SentenceWrapper.new(dictionary,'grammar','${OTHER}')
		assert_equal('some other', sentence.write)

		srand 7
		sentence = SentenceWrapper.new(dictionary,'grammar','${OTHER}')
		sentence.other_word_chance = 0.5
		assert_equal('some other', sentence.write)
	end

	def test_handle_adverb
		grammar = GenericGrammar.new
		dictionary = Dictionary.new

		dictionary.read "N 100 beast\nV 100 smiles\nD 100 horribly"
		3.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${ADV}')
			assert_equal 'beast smiles horribly', sentence.write
		end

		dictionary.read "N 100 beast SEMANTIC(EVIL)\nV 100 smiles\nD 100 horribly\nD 100 lovely NOT_WITH(EVIL)"
		3.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${ADV}')
			assert_equal 'beast smiles horribly', sentence.write
		end
		dictionary.read "N 100 beast SEMANTIC(EVIL,BEAST)\nV 100 smiles\nD 100 horribly\nD 100 lovely NOT_WITH(EVIL,HORRIBLE)"
		3.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${ADV}')
			assert_equal 'beast smiles horribly', sentence.write
		end

		dictionary.read "N 100 beast SEMANTIC(EVIL)\nV 100 smiles\nD 100 horribly\nD 100 lovely ONLY_WITH(CUTE)"
		3.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${ADV}')
			assert_equal 'beast smiles horribly', sentence.write
		end
		dictionary.read "N 100 beast\nV 100 smiles\nD 100 horribly\nD 100 lovely ONLY_WITH(CUTE)"
		3.times do
			sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${VERB} ${ADV}')
			assert_equal 'beast smiles horribly', sentence.write
		end
	end

	def test_handle_empty_dictionary
		dictionary = Dictionary.new
		sentence = SentenceWrapper.new(dictionary,'grammar','${NOUN} ${ADJ} ${VERB}')
		assert_equal('', sentence.write.strip)
	end

	def test_debug
		dictionary_text = "N 100 foo\nA 100 bar"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		sentence = SentenceWrapper.new(dictionary,grammar,'${NOUN1} ${ADJ}')
		sentence.debug = true
# 		assert_equal('foo bar END', sentence.write) # TODO FIXME !!!
	end

	def test_set_subject
		dictionary_text = "N 100 foo\nA 100 cool"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		subject = Noun.new('bar',[],0,1)
		grammar = PolishGrammar.new

		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${SUBJ2} ${SUBJ3}')
		sentence.subject = subject
		assert_equal('bar foo foo', sentence.write)

		sentence = SentenceWrapper.new(dictionary,grammar,'${SUBJ} ${ADJ}')
		sentence.subject = subject
		assert_equal('bar cool', sentence.write)
	end

	def test_empty_nouns
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		dictionary_text = <<-END
N 100 "" PERSON(2)
N  10 "foo"
		END
		dictionary.read(dictionary_text)
		10.times do
			assert_equal('foo', SentenceWrapper.new(dictionary,grammar,'${NOUN}').write)
			assert_equal('foo', SentenceWrapper.new(dictionary,grammar,'${SUBJ(NE)}').write)
			assert_equal('', SentenceWrapper.new(dictionary,grammar,'${SUBJ(EMPTY)}').write)
		end

	end

	def test_only_subj_only_obj
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		dictionary_text = <<-END
N 100 noun1 ONLY_SUBJ
N  10 noun2
V 100 verb1 OBJ(4)
		END
		dictionary.read(dictionary_text)
		10.times do
			assert_equal('verb1 noun2', SentenceWrapper.new(dictionary,grammar,'${VERB(2)} ${OBJ}').write)
		end

		# test OBJ_FREQ
		dictionary_text = <<-END
N 100 noun1 ONLY_SUBJ
N  0  noun2 OBJ_FREQ(10)
V 100 verb1 OBJ(4)
		END
		dictionary.read(dictionary_text)
		10.times do
			assert_equal('verb1 noun2', SentenceWrapper.new(dictionary,grammar,'${VERB(2)} ${OBJ}').write)
		end

		dictionary_text = <<-END
N 100 noun1 ONLY_OBJ
N  10 noun2
		END
		dictionary.read(dictionary_text)
		10.times do
			assert_equal('noun2', SentenceWrapper.new(dictionary,grammar,'${SUBJ}').write)
		end

		dictionary_text = <<-END
N 100 noun1 ONLY_OBJ
		END
		dictionary.read(dictionary_text)
		10.times do
			assert_equal('noun1', SentenceWrapper.new(dictionary,grammar,'${SUBJ(IG_ONLY)}').write)
		end
	end
end

class SentenceBuilderTest < Test::Unit::TestCase
	def test_create_sentence
		dictionary_text = "N 100 foo\nN 100 bar"
		dictionary = ControlledDictionary.new
		dictionary.read dictionary_text
		dictionary.set_indices NOUN, [0, 1]
		grammar = PolishGrammar.new

		builder = SentenceBuilder.new(dictionary,grammar,'a ${NOUN} b',100)
		sentence1 = builder.create_sentence
		sentence2 = builder.create_sentence
		sentence1.double_noun_chance = 0
		sentence2.double_noun_chance = 0
		text1 = sentence1.write
		text2 = sentence2.write
		assert_equal('a foo b', text1)
		assert_equal('a bar b', text2)
		assert_nil(sentence1.subject)
		assert_nil(sentence2.subject)
	end
end

class SentenceManagerTest < Test::Unit::TestCase
	def test_read
		srand
		input = <<-END

#foo

100 okeee # inline comment
 10 also ok
-1 also bad negative

1 owaśtam
		END
		mgr = SentenceManager.new("dictionary",'grammar')
		mgr.read(input)
		assert_equal(3, mgr.size)
		mgr.read(input)
		assert_equal(3, mgr.size)
		srand 1
		assert_equal('okeee', mgr.random_sentence.write)
	end

	def test_nonlatin_characters
		srand
		mgr = SentenceManager.new('dictionary','grammar')
		mgr.read '10 ну, давай'
		assert_equal 'ну, давай', mgr.random_sentence.write
	end

	def test_get_random
		srand
		input = <<-END
0 never
1 sometimes
0 nevernever
2 is
0 neverever
		END
		mgr = SentenceManager.new("dictionary",'grammar')
		mgr.read(input)
		assert_equal(5,mgr.size)
		100.times() do
			sentence = mgr.random_sentence.write
			assert(%w{sometimes is}.include?(sentence))
		end
	end

	def test_validation
		mgr = SentenceManager.new("dictionary",'grammar')

		assert_raise(RuntimeError) { mgr.read('10 ${SUBJ ${VERB}') }

		input = '10 ${SUBJ} ${VERB} ${SUBJ2}' # ok
		mgr.read(input)

		input = '10 ${ADJ}' # no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN2} ${ADJ}' # no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN} ${ADJ} ${NOUN2} {$ADJ2}' # ok
		mgr.read(input)

		input = '10 ${VERB}' # no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN2} ${VERB}' # wrong verb, no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN2} ${VERB2} ${OBJ}' # wrong object, no such noun
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${NOUN} ${VERB} ${NOUN2} {$VERB2}' # ok
		mgr.read(input)

		mgr.read('10 ${VERB(1)}')
		mgr.read('10 ${VERB(1)} ${OBJ}')
		assert_raise(RuntimeError) { mgr.read('10 ${VERB} ${OBJ}') }
		assert_raise(ArgumentError) { mgr.read('10 ${VERB(a)}') }
		assert_raise(RuntimeError) { mgr.read('10 ${VERB(14)}') }

		# unclosed brackets
		assert_raise(RuntimeError) { mgr.read('10 ${SUBJ ${VERB} ${SUBJ2}') }
		assert_raise(RuntimeError) { mgr.read('10 ${SUBJ} ${VERB ${SUBJ2}') }
		assert_raise(RuntimeError) { mgr.read('10 ${SUBJ} ${VERB} ${SUBJ2') }
	end
end
