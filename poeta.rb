#!/usr/bin/ruby -w

require 'poem'
require 'sentence'

dictionary = "dictionary"
sentence_mgr = SentenceManager.new(dictionary)
sentence_mgr.read(File.open('default.cfg'))
poem = Poem.new("dictionary","grammar",sentence_mgr)
puts poem.text
