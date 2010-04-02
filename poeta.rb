#!/usr/bin/ruby -w

require 'poem'
require 'dictionary'
require 'sentence'

include Grammar

grammar = PolishGrammar.new
File.open('pl.aff') { |f| grammar.read_rules(f) }
dictionary = SmartRandomDictionary.new
File.open('default.dic') { |f| dictionary.read(f) }
sentence_mgr = SentenceManager.new(dictionary,grammar,true)
File.open('default.cfg') { |f| sentence_mgr.read(f) }
poem = Poem.new(dictionary,grammar,sentence_mgr)
puts poem.text
