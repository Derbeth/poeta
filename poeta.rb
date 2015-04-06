#!/usr/bin/ruby

require 'optparse'

require './poem'
require './poem_files'
require './smart_random_dictionary'
require './configuration'
require './preprocessor'
require './dictionary_statistics'
require './sentence_manager'

include Grammar
include Poeta

version = '4.0 pre-alpha'
dictionary = nil
language = 'pl'
debug = false
forced_seed = nil
show_stats = false
stat_opts = {}
conf = PoetryConfiguration.new

GRAMMAR_FOR_LANGS = {'de' => GermanGrammar, 'en' => EnglishGrammar, 'pl' => PolishGrammar}
GRAMMAR_FOR_LANGS.default = GenericGrammar

OptionParser.new do |opts|
	opts.banner = "Usage: poeta.rb [options] [dictionary]"

	opts.on("-l", "--language LANGUAGE", "Use language (defaults to 'pl')") do |l|
		language = l
	end
	opts.separator ""
	opts.on("-d", "--debug", "Run in debug mode") do |d|
		debug = true
		conf.debug = true
	end
	opts.on('-s', '--seed SEED', "Feed the random generator with given rand seed") do |s|
		forced_seed = s.to_i
	end
	opts.on('--stats [SORTING]', "Just print statistics of the used dictionary",
	        "You can define sorting like 'freq,desc'") do |sort|
		show_stats = true
		if sort && sort !~ /^\w+,\w+$/
			$stderr.puts "Wrong stats option: '#{sort}'; expected something like 'freq,desc'"
		elsif sort
			key,order = sort.split(',')
			stat_opts = {:sort_key => key.to_sym, :sort_order => order.to_sym}
		end
	end

	opts.separator ""
	opts.separator "Common options:"
	opts.on_tail('-h','--help','Show full help') do
		puts opts
		exit
	end
	opts.on_tail('-v','--version','Show program version') do
		puts "Poeta v#{version}"
		exit
	end
end.parse!

raise "expects none or one argument" if ARGV.size > 1
poem_files = PoemFiles.new(language, ARGV[0])
poem_files.resolve!

grammar = GRAMMAR_FOR_LANGS[language].new
preprocessor = Preprocessor.new(conf)

File.open(poem_files.grammar_file) { |f| grammar.read_rules(f) }
dictionary = SmartRandomDictionary.new(5)
File.open(poem_files.dictionary_file) { |f| dictionary.read(preprocessor.process(f)) }
sentence_mgr = SentenceManager.new(dictionary,grammar,conf)
File.open(poem_files.sentences_file) { |f| sentence_mgr.read(preprocessor.process(f)) }
title_sentence_mgr = SentenceManager.new(dictionary,grammar,conf)
File.open(poem_files.title_sentences_file) { |f| title_sentence_mgr.read(f) }

used_config_files = []
[poem_files.general_config_file, poem_files.dictionary_config_file].each do |file|
	next unless File.exist?(file)
	File.open(file) { |f| conf.read(f) && used_config_files << file }
end

errors = dictionary.validate_with_grammar(grammar)
unless errors.empty?
	errors.each { |err| conf.logger.warn "warn: #{err[:message]}" }
end

if show_stats
	puts "dictionary: #{poem_files.dictionary_file}"
	DictionaryStatistics.new.print(dictionary, stat_opts)
else
	if forced_seed
		srand(forced_seed)
	else
		srand
	end

	begin
		poem = Poem.new(sentence_mgr,title_sentence_mgr,conf)
		puts poem.text
	rescue
		puts 'Error: ', $!.inspect, $@
	end

	if debug
		puts
		puts "dictionary: #{poem_files.dictionary_file} sentences: #{poem_files.sentences_file} titles: #{poem_files.title_sentences_file}"
		puts "grammar: #{grammar.class}"
		puts "config files: #{used_config_files.join(' ')}"
		puts "configuration: #{conf.summary}"
		puts "rand seed: #{srand}"
	end
end
