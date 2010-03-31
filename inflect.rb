#!/usr/bin/ruby -w

require 'dictionary'
require 'optparse'

include Grammar

dict_file = 'default'
only_list = false
OptionParser.new do |opts|
	opts.banner = "Usage: inflect.rb [options] word"

	opts.separator ""
	opts.on("-d", "--dict DICTIONARY", "Open dictionary other than default") do |d|
		dict_file = d
	end
	opts.on("-l", "--list-only", "Only lists found words, does not inflect them") do |d|
		only_list = true
	end
	opts.separator ""
	opts.separator "Common options:"
	opts.on_tail('-h','--help','Show full help') do
		puts opts
		exit
	end
end.parse!

raise "Please provide a name" if (ARGV.size == 0)

dict_file += '.dic' unless dict_file =~ /\.dic/

dictionary = Dictionary.new
dictionary.read(File.open(dict_file))

grammar = PolishGrammar.new
File.open('pl.aff') { |f| grammar.read_rules(f) }

ARGV.each do |to_find|
	mask = to_find.gsub(/\*/, '.*')
	any_found = false
	dictionary.find_all {|wrd| wrd.text =~ /#{mask}/ }.sort.each do |word|
		any_found = true
		if only_list:
			puts word.text
			next
		end

		word.all_forms.each do |form|
			puts "#{GrammarForm.pretty_print(form)}  #{word.text}"
		end
	end
	puts "'#{to_find}' not found" unless any_found
end
