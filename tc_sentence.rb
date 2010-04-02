#!/usr/bin/ruby -w
require 'test/unit'

require 'sentence'

include Grammar

class SentenceTest < Test::Unit::TestCase
	def test_trim
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)

		sentence = Sentence.new(dictionary,'grammar','')
		assert_equal('', sentence.write)
		sentence = Sentence.new(dictionary,'grammar','  ')
		assert_equal('', sentence.write)
		sentence = Sentence.new(dictionary,'grammar',' ${VERB} ${SUBJ}   ${SUBJ} ')
		assert_equal('foo foo', sentence.write)
	end

	def test_handle_subject
		dictionary_text = 'N 100 foo'
		dictionary = Dictionary.new
		dictionary.read(dictionary_text)

		sentence = Sentence.new(dictionary,'grammar','a ${SUBJ} b')
		text = sentence.write
		assert_equal('a foo b', text)
		assert_equal('foo', sentence.subject.text)

		srand 1
		dictionary2_text = "N 100 foo\nN 100 bar"
		dictionary2 = Dictionary.new
		dictionary2.read(dictionary2_text)
		sentence = Sentence.new(dictionary2,'grammar','a ${SUBJ} ${SUBJ2} b')
		text = sentence.write
		assert_equal('a foo bar b', text)
		assert_equal('foo', sentence.subject.text)
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
		assert_equal('foo bar END', sentence.write)
	end

	def test_set_sentence
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

100 okeee
 10 also okee
-1 also bad negative

1 owaśtam
		END
		mgr = SentenceManager.new("dictionary",'grammar')
		mgr.read(input)
		assert_equal(3, mgr.size)
		mgr.read(input)
		assert_equal(3, mgr.size)
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
	end
end
