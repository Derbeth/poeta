#!/usr/bin/ruby -w

require 'simplecov'
SimpleCov.start do
  add_filter "/test/"
end

require 'test/unit'

# Currently tests do not work with jruby-1.6.8 because of the difference in behaviour of srand()
# jruby-1.7.0 works fine

require './test/tc_configuration'
require './test/tc_preprocessor'
require './test/tc_sentence_splitter'
require './test/tc_grammar'
require './test/tc_word'
require './test/tc_dictionary'
require './test/tc_sentence'
require './test/tc_sentence_manager'
require './test/tc_verse'
require './test/tc_poem'
