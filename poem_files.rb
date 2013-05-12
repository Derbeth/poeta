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
			@sentences_file = "#{DICT_DIR}/#@dictionary.cfg"
			unless @io.exists?(@sentences_file)
				@sentences_file = "#{DICT_DIR}/#@default_dict.cfg"
			end
			@title_sentences_file = "titles.cfg"
			@grammar_file = "#{LANG_DIR}/#@language.aff"

			@general_config_file = "poetry.yml"
			@dictionary_config_file = "#{DICT_DIR}/#@dictionary.yml"

			[@dictionary_file, @sentences_file, @title_sentences_file, @grammar_file].each do |file|
				raise "#{file} does not exist" unless @io.exists?(file)
			end
		end

		private

		DICT_DIR = 'dictionaries'
		LANG_DIR = 'languages'
	end
end
