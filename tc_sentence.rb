#!/usr/bin/ruby -w
require 'test/unit'

require 'sentence'

include Grammar

class StringTest < Test::Unit::TestCase
	def test_ljust
		assert_equal("foo   ", "foo".ljust(6))
		assert_equal("foo   ", "foo".fixed_ljust(6))
		assert_equal("foó   ", "foó".fixed_ljust(6))
		assert_equal("fóo   ", "fóo".fixed_ljust(6))
		assert_equal("fóó   ", "fóó".fixed_ljust(6))
	end
end

class SentenceTest < Test::Unit::TestCase

	def setup
		srand
	end

	def test_trim
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		sentence = Sentence.new(dictionary,grammar,'')
		assert_equal('', sentence.write)
		sentence = Sentence.new(dictionary,grammar,'  ')
		assert_equal('', sentence.write)
		sentence = Sentence.new(dictionary,grammar,' ${VERB} ${SUBJ}   ${SUBJ} ')
		assert_equal('foo foo', sentence.write)
	end

	def test_write
		pattern = '${NOUN}'
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		dictionary.read('N 100 foo')
		sentence = Sentence.new(dictionary,grammar,pattern)
		assert_equal('${NOUN}', sentence.pattern)
		sentence.write
		assert_equal('${NOUN}', sentence.pattern)
	end

	def test_handle_subject
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		sentence = Sentence.new(dictionary,grammar,'a ${SUBJ} b')
		text = sentence.write
		assert_equal('a foo b', text)
		assert_equal('foo', sentence.subject.text)

		srand 1
		dictionary2_text = "N 100 foo\nN 100 bar"
		dictionary2 = Dictionary.new
		dictionary2.read(dictionary2_text)
		sentence = Sentence.new(dictionary2,grammar,'a ${SUBJ} ${SUBJ2} b')
		text = sentence.write
		assert_equal('a foo bar b', text)
		assert_equal('foo', sentence.subject.text)
	end

	def test_handle_noun
		dictionary = Dictionary.new
		grammar = PolishGrammar.new

		dictionary.read("N 100 pora/a")
		grammar.read_rules("N a 6 a ze ra")
		sentence = Sentence.new(dictionary,grammar,'${NOUN(6)}')
		assert_equal('porze', sentence.write)

		sentence = Sentence.new(dictionary,grammar,'${SUBJ(6)}')
		assert_equal('porze', sentence.write)
	end

	def test_handle_adjective
		dictionary_text = "N 100 stuff\nA 100 cool"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		sentence = Sentence.new(dictionary,grammar,'?${ADJ} ${NOUN}?')
		assert_equal('?cool stuff?', sentence.write)

		srand 1
		dictionary2_text = "N 100 stuff\nN 100 things\nA 100 cool\nA 100 bad"
		dictionary2 = Dictionary.new
		dictionary2.read(dictionary2_text)

		sentence = Sentence.new(dictionary2,grammar,'${ADJ1} ${NOUN} ${ADJ2} ${NOUN2}')
		assert_equal('cool stuff bad things', sentence.write)
		sentence = Sentence.new(dictionary2,grammar,'${NOUN1} ${ADJ1} ${NOUN2} ${ADJ1}')
		assert_equal('things bad stuff bad', sentence.write)

		dictionary.read("N 100 psy n Pl\nA 100 zły/a")
		grammar.read_rules("A a 211 y e y")
		sentence = Sentence.new(dictionary,grammar,'${ADJ} ${NOUN}')
		assert_equal('złe psy', sentence.write)

		dictionary.read("N 100 pory f\nA 100 dobry/a")
		grammar.read_rules("A a 302 y ej y")
		sentence = Sentence.new(dictionary,grammar,'${ADJ(2)} ${NOUN}')
		assert_equal('dobrej pory', sentence.write)

		# two adjectives to one noun
		srand 1
		dictionary.read("N 100 pora f\nA 100 dobry/a\nA 100 prosty/a")
		grammar.read_rules("A a 301 y a y")
		sentence = Sentence.new(dictionary,grammar,'${ADJ} ${ADJ} ${NOUN}')
		assert_equal('prosta dobra pora', sentence.write)

		srand 1
		dictionary.read("N 100 pora f\nA 100 dobry/a\nA 100 prosty/a")
		grammar.read_rules("A a 301 y a y")
		sentence = Sentence.new(dictionary,grammar,'${ADJ} ${ADJ} ${SUBJ}')
		assert_equal('prosta dobra pora', sentence.write)

		dictionary.read(%Q{N 100 "" PERSON(2)\nA 100 dobry\nV 100 rozumieć/a})
		grammar.read_rules("V a 2 ć sz ć")
		sentence = Sentence.new(dictionary,grammar,'${ADJ} ${SUBJ} ${VERB}')
		assert_equal('rozumiesz', sentence.write)
	end

	def test_handle_animate_inanimate
		dictionary = Dictionary.new
		grammar = PolishGrammar.new
		grammar.read_rules("A a 104 y ego y/A")
		dictionary.read("A 100 dobry/a\nN 100 czas m nan")
		sentence = Sentence.new(dictionary,grammar,'widzę ${ADJ(4)} ${NOUN(4)}')
		assert_equal('widzę dobry czas', sentence.write)

		dictionary.read("A 100 dobry/a\nN 100 psa m")
		sentence = Sentence.new(dictionary,grammar,'widzę ${ADJ(4)} ${NOUN(4)}')
		assert_equal('widzę dobrego psa', sentence.write)
	end

	def test_handle_semantic
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		dictionary.read("N 100 work SEMANTIC(GOOD)\nA 100 good ONLY_WITH(GOOD)\n")
		sentence = Sentence.new(dictionary,grammar,'${ADJ} ${NOUN}')
		assert_equal('good work', sentence.write)
		dictionary.read("N 100 work\nA 100 good ONLY_WITH_W(work)\n")
		sentence = Sentence.new(dictionary,grammar,'${ADJ} ${NOUN}')
		assert_equal('good work', sentence.write)

		# noun -> adjective
		dictionary.read("N 100 work SEMANTIC(GOOD)\nA 100 good\nA 100 bad NOT_WITH(GOOD)")
		10.times do
			sentence = Sentence.new(dictionary,grammar,'${ADJ} ${SUBJ}')
			assert_equal('good work', sentence.write)
		end
		dictionary.read("N 100 work\nA 100 good\nA 100 bad NOT_WITH_W(work)")
		10.times do
			sentence = Sentence.new(dictionary,grammar,'${ADJ} ${SUBJ}')
			assert_equal('good work', sentence.write)
		end

		dictionary.read("N 100 work SEMANTIC(GOOD)\nA 100 good NOT_WITH(BAD)\n")
		sentence = Sentence.new(dictionary,grammar,'${ADJ} ${SUBJ}')
		assert_equal('good work', sentence.write)

		dictionary.read("N 100 work SEMANTIC(GOOD)\nA 100 good\nA 100 bad ONLY_WITH(BAD)")
		10.times do
			sentence = Sentence.new(dictionary,grammar,'${ADJ} ${NOUN}')
			assert_equal('good work', sentence.write)
		end
		dictionary.read("N 100 work\nA 100 good\nA 100 bad ONLY_WITH_W(idea)")
		10.times do
			sentence = Sentence.new(dictionary,grammar,'${ADJ} ${NOUN}')
			assert_equal('good work', sentence.write)
		end

		# verb -> noun object
		dictionary.read("V 100 purge OBJ(1) TAKES_ONLY(EVIL)\nN 100 evil SEMANTIC(EVIL)\nN 100 good SEMANTIC(GOOD)")
		10.times do
			sentence = Sentence.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('purge evil', sentence.write)
		end
		dictionary.read("V 100 purge OBJ(1) TAKES_NO(GOOD)\nN 100 evil SEMANTIC(EVIL)\nN 100 good SEMANTIC(GOOD)")
		10.times do
			sentence = Sentence.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('purge evil', sentence.write)
		end

		dictionary.read("V 100 spread OBJ(1) TAKES_ONLY_W(good)\nN 100 evil\nN 100 good")
		10.times do
			sentence = Sentence.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('spread good', sentence.write)
		end
		dictionary.read("V 100 spread OBJ(1) TAKES_NO_W(evil)\nN 100 evil\nN 100 good")
		10.times do
			sentence = Sentence.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
			assert_equal('spread good', sentence.write)
		end

		# verb -> verb object
		srand 2
		dictionary.read("V 1000 muszę INF\nV 100 chcieć\nV 30 lecieć") # no semantic - expect wrong result
		sentence = Sentence.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_equal('muszę chcieć', sentence.write)
		srand 2
		dictionary.read("V 1000 muszę INF TAKES_NO(MODAL)\nV 100 chcieć SEMANTIC(MODAL)\nV 30 lecieć SEMANTIC(MOVE)")
		sentence = Sentence.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_equal('muszę lecieć', sentence.write)
	end

	def test_handle_verb
		dictionary = Dictionary.new
		dictionary.read("N 100 lipy f Pl\nV 100 rosnąć/a")
		grammar = PolishGrammar.new
		grammar.read_rules("V a 13 ć 0 ć")

		sentence = Sentence.new(dictionary,grammar,'${NOUN} ${VERB}')
		assert_equal('lipy rosną', sentence.write)

		dictionary.read("N 100 lipy f Pl\nV 100 rosnąć/a REFLEXIVE")
		sentence = Sentence.new(dictionary,grammar,'${NOUN} ${VERB}')
		assert_equal('lipy rosną się', sentence.write)

		dictionary.read("V 100 rosnąć/a")
		sentence = Sentence.new(dictionary,grammar,'${VERB(13)}')
		assert_equal('rosną', sentence.write)

		dictionary.read("N 100 lipa f\nV 100 rosnąć/a")
		sentence = Sentence.new(dictionary,grammar,'${NOUN}. ${VERB2(13)}')
		assert_equal('lipa. rosną', sentence.write)

		dictionary.read("V 100 rosnąć/a")
		grammar.read_rules("V a 1 ąć ę ąć")
		sentence = Sentence.new(dictionary,grammar,'${VERB(1)}')
		assert_equal('rosnę', sentence.write)

		dictionary.read("N 100 lipa/b f\nV 100 uderzać/a OBJ(4)")
		grammar.read_rules("N b 4 a ę a\nV a 1 ć m ć")
		sentence = Sentence.new(dictionary,grammar,'${VERB(1)} ${OBJ}')
		assert_equal('uderzam lipę', sentence.write)
	end

	def test_handle_object
		dictionary = Dictionary.new
		dictionary.read("N 100 pies\nN 100 kot/a\nV 100 je")
		srand 1
		assert_equal('pies', dictionary.get_random(NOUN).text)
		srand 1
		grammar = PolishGrammar.new
		grammar.read_rules("N a 4 0 a .\nN a 15 0 ami .")

		sentence = Sentence.new(dictionary,grammar,'${NOUN} ${OBJ} ${VERB}')
		assert_equal('pies je', sentence.write)

		dictionary.read("N 100 pies\nN 100 kot/a\nV 100 je OBJ(4)")
		sentence = Sentence.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
		assert_equal('pies je kota', sentence.write)

		dictionary.read("N 100 pies\nN 100 kot/a Pl\nV 100 goni OBJ(za,5)")
		sentence = Sentence.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
		assert_equal('pies goni za kotami', sentence.write)
	end

	def test_object_wont_equal_subject
		dictionary = Dictionary.new
		dictionary.read("N 100 pies\nN 30 kota/a\nV 100 goni OBJ(4)")
		srand 2
		assert_equal('pies', dictionary.get_random_subject.text)
		assert_equal('pies', dictionary.get_random_object.text)
		srand 2
		grammar = PolishGrammar.new
		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies goni kota', sentence.write)
	end

	def test_object_preposition_letter_change
		grammar = PolishGrammar.new
		dictionary = Dictionary.new
		srand 1
		dictionary.read("N 100 pies\nN 30 zebrą\nV 100 idzie OBJ(z,5)")
		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie z zebrą', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 zdradą\nV 100 idzie OBJ(z,5)")
		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie ze zdradą', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 szkołą\nV 100 idzie OBJ(z,5)")
		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie ze szkołą', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 szansą\nV 100 idzie OBJ(z,5)")
		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie z szansą', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 skrętem\nV 100 idzie OBJ(z,5)")
		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie ze skrętem', sentence.write)
		srand 1
		dictionary.read("N 100 pies\nN 30 walce\nV 100 idzie OBJ(w,6)")
		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie w walce', sentence.write)
		dictionary.read("N 100 pies\nN 30 wronie\nV 100 idzie OBJ(w,6)")
		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${VERB} ${OBJ}')
		assert_equal('pies idzie we wronie', sentence.write)
		# TODO ode mnie?
	end

	def test_handle_infinitive_object
		dictionary = Dictionary.new
		dictionary.read("N 100 pies\nV 100 chce INF\nV 30 jeść")
		srand 1
		assert_equal('chce', dictionary.get_random(VERB).text)
		assert_equal('chce', dictionary.get_random(VERB).text)
		srand 1

		grammar = PolishGrammar.new
		sentence = Sentence.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
		assert_equal('pies chce jeść', sentence.write)

		dictionary.read("N 100 pies\nV 100 chce INF\nV 30 przejść REFL")
		sentence = Sentence.new(dictionary,grammar,'${NOUN} ${VERB} ${OBJ}')
		assert_equal('pies chce się przejść', sentence.write)
	end

	def test_handle_other
		dictionary = Dictionary.new
		dictionary.read('O 100 "some other"')

		srand 7
		draw = rand
		sentence = Sentence.new(dictionary,'grammar','')
		default_other_choice = sentence.other_word_chance
		assert draw < default_other_choice && draw < 0.5, "got #{draw} >= #{default_other_choice}"
		srand 3
		draw = rand
		assert draw > 0.5, "got #{draw}"

		srand 3
		sentence = Sentence.new(dictionary,'grammar','${OTHER}')
		sentence.other_word_chance = 0.5
		assert_equal('', sentence.write)

		srand 7
		sentence = Sentence.new(dictionary,'grammar','${OTHER}')
		assert_equal('some other', sentence.write)

		srand 7
		sentence = Sentence.new(dictionary,'grammar','${OTHER}')
		sentence.other_word_chance = 0.5
		assert_equal('some other', sentence.write)
	end

	def test_handle_adverb
		dictionary = Dictionary.new
		dictionary.read('D 100 fast')

		sentence = Sentence.new(dictionary,'grammar','${ADV}')
		assert_equal('fast', sentence.write)
	end

	def test_handle_empty_dictionary
		dictionary = Dictionary.new
		sentence = Sentence.new(dictionary,'grammar','${NOUN} ${ADJ} ${VERB}')
		assert_equal('', sentence.write.strip)
	end

	def test_debug
		dictionary_text = "N 100 foo\nA 100 bar"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		sentence = Sentence.new(dictionary,grammar,'${NOUN1} ${ADJ}')
		sentence.debug = true
# 		assert_equal('foo bar END', sentence.write) # TODO FIXME !!!
	end

	def test_set_subject
		dictionary_text = "N 100 foo\nA 100 cool"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		subject = Noun.new('bar',[],0,1)
		grammar = PolishGrammar.new

		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${SUBJ2} ${SUBJ3}')
		sentence.subject = subject
		assert_equal('bar foo foo', sentence.write)

		sentence = Sentence.new(dictionary,grammar,'${SUBJ} ${ADJ}')
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
			assert_equal('foo', Sentence.new(dictionary,grammar,'${NOUN}').write)
			assert_equal('foo', Sentence.new(dictionary,grammar,'${SUBJ(NE)}').write)
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
			assert_equal('verb1 noun2', Sentence.new(dictionary,grammar,'${VERB(2)} ${OBJ}').write)
		end

		dictionary_text = <<-END
N 100 noun1 ONLY_OBJ
N  10 noun2
		END
		dictionary.read(dictionary_text)
		10.times do
			assert_equal('noun2', Sentence.new(dictionary,grammar,'${SUBJ}').write)
		end

		dictionary_text = <<-END
N 100 noun1 ONLY_OBJ
		END
		dictionary.read(dictionary_text)
		10.times do
			assert_equal('noun1', Sentence.new(dictionary,grammar,'${SUBJ(IG_ONLY)}').write)
		end
	end
end

class SentenceBuilderTest < Test::Unit::TestCase
	def test_create_sentence
		srand 1
		dictionary_text = "N 100 foo\nN 100 bar"
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)
		grammar = PolishGrammar.new

		builder = SentenceBuilder.new(dictionary,grammar,'a ${NOUN} b',100)
		sentence1 = builder.create_sentence
		sentence2 = builder.create_sentence
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

		input = '10 ${SUBJ} ${VERB} ${SUBJ}' # double subject
		assert_raise(RuntimeError) { mgr.read(input) }

		input = '10 ${SUBJ} ${VERB} ${NOUN}' # double noun/subject
		assert_raise(RuntimeError) { mgr.read(input) }

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
	end
end
