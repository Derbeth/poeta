#!/usr/bin/ruby -w
require 'test/unit'

# Currently tests do not work with jruby-1.6.8 because of the difference in behaviour of srand()
# jruby-1.7.0 works fine

require './tc_grammar'
require './tc_word'
require './tc_dictionary'
require './tc_sentence'
require './tc_sentence_manager'
require './tc_poem'
