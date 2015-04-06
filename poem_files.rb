# -*- encoding: utf-8 -*-

module Poeta
	class PoemFiles
		attr_reader :dictionary_file, :grammar_file, :sentences_file, :title_sentences_file
		attr_reader :dictionary_config_file, :general_config_file
		attr_writer :io

		def initialize(language,dictionary=nil)
			@io = File
			@language = language
			@default_dict = "default_#{language}"
			@dictionary = dictionary || @default_dict
		end

		def resolve!
			@dictionary_file = "#{DICT_DIR}/#@dictionary.dic"
			@sentences_file = first_existing("#{DICT_DIR}/#@dictionary.cfg", "#{DICT_DIR}/#@default_dict.cfg")
			@title_sentences_file = first_existing("#{DICT_DIR}/#@dictionary.titles.cfg", "#{DICT_DIR}/#@default_dict.titles.cfg", "titles.cfg")
			@grammar_file = "#{LANG_DIR}/#@language.aff"

			@general_config_file = "poetry.yml"
			@dictionary_config_file = "#{DICT_DIR}/#@dictionary.yml"

			[@dictionary_file, @sentences_file, @title_sentences_file, @grammar_file].each do |file|
				raise "#{file} does not exist" unless @io.exist?(file)
			end
		end

		private

		DICT_DIR = 'dictionaries'
		LANG_DIR = 'languages'

		# returns first of the given paths that exists, or the last one if none exists
		def first_existing(*paths)
			last_path = nil
			paths.each do |path|
				last_path = path
				break if @io.exist?(path)
			end
			last_path
		end
	end
end
