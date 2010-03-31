#!/usr/bin/ruby -w

require 'dictionary'
require 'optparse'

include Grammar

dict_file = 'default'
OptionParser.new do |opts|
	opts.banner = "Usage: inflect.rb [options] word"

	opts.separator ""
	opts.on("-d", "--dict DICTIONARY", "Open dictionary other than default") do |d|
		dict_file = d
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

ARGV.each do |word|
	mask = word.gsub(/\*/, '.*')
	any_found = false
	dictionary.find_all {|word| word.text =~ /#{mask}/ }.sort.each do |found|
		any_found = true

		puts found.text
	end
	puts "'#{word}' not found" unless any_found
end
