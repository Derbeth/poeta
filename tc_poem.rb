#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'

require './poem'

include Grammar

class VerseTest < Test::Unit::TestCase
	class StubSentenceManager
		def initialize(*sentences)
			raise "should be enumerable" unless sentences.respond_to?(:each)
			@sentences=sentences
			@sentence_index=0
		end
		def random_sentence
			retval = @sentences[@sentence_index]
			@sentence_index += 1
			retval
		end
	end

	class NoSubjectSentence
		def write
			''
		end
		def subject
			nil
		end
	end

	class WithSubjectSentence
		def initialize(subject)
			@subject=Noun.new(subject,[],100,MASCULINE)
		end
		def write
			''
		end
		def subject
			@subject
		end
	end


	def test_find_subject
		no = NoSubjectSentence.new
		some = WithSubjectSentence.new('some')
		other = WithSubjectSentence.new('other')
		empty = WithSubjectSentence.new('')

		verse1 = Verse.new(StubSentenceManager.new(no,no,no,no))
		assert_equal(nil, verse1.subject)
		verse2 = Verse.new(StubSentenceManager.new(no,some,no,other))
		assert_equal('some', verse2.subject.text)
		verse3 = Verse.new(StubSentenceManager.new(some,no,no,no))
		assert_equal('some', verse3.subject.text)
		verse4 = Verse.new(StubSentenceManager.new(no,no,no,some))
		assert_equal('some', verse4.subject.text)
		verse5 = Verse.new(StubSentenceManager.new(empty,empty,empty,empty))
		assert_equal(nil, verse5.subject)
	end
end
