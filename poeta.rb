#!/usr/bin/ruby -w

require 'optparse'

require 'poem'
require 'dictionary'
require 'sentence'

include Grammar

dictionary = 'default'
grammar = 'pl'
debug = false

OptionParser.new do |opts|
	opts.banner = "Usage: poeta.rb [options] [dictionary]"

	opts.separator ""
	opts.on("-d", "--debug", "Run in debug mode") do |d|
		debug = true
	end
	opts.separator ""
	opts.separator "Common options:"
	opts.on_tail('-h','--help','Show full help') do
		puts opts
		exit
	end
end.parse!

raise "expects none or one argument" if ARGV.size > 1
dictionary = ARGV[0] if ARGV[0]

dictionary_file = dictionary
sentences_file = dictionary

dictionary_file += '.dic' if dictionary_file !~ /\.dic$/
sentences_file += '.cfg' if sentences_file !~ /\.cfg$/
raise "#{dictionary_file} does not exist" unless File.exists?(dictionary_file)
raise "#{sentences_file} does not exist" unless File.exists?(sentences_file)

grammar = PolishGrammar.new
File.open('pl.aff') { |f| grammar.read_rules(f) }
dictionary = SmartRandomDictionary.new
File.open(dictionary_file) { |f| dictionary.read(f) }
sentence_mgr = SentenceManager.new(dictionary,grammar,true,debug)
File.open(sentences_file) { |f| sentence_mgr.read(f) }
poem = Poem.new(dictionary,grammar,sentence_mgr)
puts poem.text
