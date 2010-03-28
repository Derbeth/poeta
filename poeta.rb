#!/usr/bin/ruby -w

require 'poem'
require 'dictionary'
require 'sentence'

include Grammar

dictionary = Dictionary.new
dictionary.read(File.open('default.dic'))
sentence_mgr = SentenceManager.new(dictionary)
sentence_mgr.read(File.open('default.cfg'))
poem = Poem.new(dictionary,"grammar",sentence_mgr)
puts poem.text
