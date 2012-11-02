#!/usr/bin/ruby -w

require 'optparse'

require './dictionary'

include Grammar

dict_file = 'default'
language = 'pl'
only_list = false
direct_input = nil
OptionParser.new do |opts|
	opts.banner = "Usage: inflect.rb [options] word"

	opts.separator ""
	opts.on("-l", "--language LANGUAGE", "Use language (defaults to 'pl')") do |l|
		language = l
	end
	opts.on("-d", "--dict DICTIONARY", "Open dictionary other than default") do |d|
		dict_file = d
	end
	opts.on("-o", "--list-only", "Only lists found words, does not inflect them") do |d|
		only_list = true
	end
	opts.on("-i", "--input LINE", "Direct input given line as dictionary") do |d|
		direct_input = d
	end
	opts.separator ""
	opts.separator "Common options:"
	opts.on_tail('-h','--help','Show full help') do
		puts opts
		exit
	end
end.parse!

dict_file += '.dic' unless dict_file =~ /\.dic/

dictionary = Dictionary.new
if direct_input
	dictionary.read(direct_input)
else
	dictionary.read(File.open(dict_file))
end

if direct_input
	words_to_list = dictionary.collect { |word| word.text }
else
	words_to_list = ARGV.find_all { true }
end

raise "Please provide words to list" if words_to_list.size == 0

grammar = PolishGrammar.new
File.open("#{language}.aff") { |f| grammar.read_rules(f) }

words_to_list.each do |to_find|
	mask = to_find.gsub(/\*/, '.*')
	any_found = false
	dictionary.find_all {|wrd| wrd.text =~ /^#{mask}$/ }.sort.each do |word|
		any_found = true
		if only_list
			puts word.text
			next
		end

		word.all_forms.each do |form|
			puts "#{GrammarForm.pretty_print(form)}  #{word.inflect(grammar,form)}"
		end
		puts "==============="
	end
	puts "'#{to_find}' not found" unless any_found
end
