#!/usr/bin/ruby -w
# -*- encoding: utf-8 -*-
require 'test/unit'
require 'rspec/mocks'

require './poem_files'

class PoemFilesTest < Test::Unit::TestCase
	def setup
		RSpec::Mocks::setup(self)

		@stub_io = double("File")
		@stub_io.stub(:exists?).and_return(false)

		having_existing_files('titles.cfg', 'languages/dsb.aff')
	end

	def test_uses_default_dictionary_for_language
		poem_files = Poeta::PoemFiles.new('dsb')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/default_dsb.dic', 'dictionaries/default_dsb.cfg')

		poem_files.resolve!

		assert_equal 'dictionaries/default_dsb.dic', poem_files.dictionary_file
	end

	def test_uses_given_dictionary
		poem_files = Poeta::PoemFiles.new('dsb', 'fancy-dict')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/default_dsb.dic', 'dictionaries/default_dsb.cfg',
			'dictionaries/fancy-dict.dic', 'dictionaries/fancy-dict.cfg')

		poem_files.resolve!

		assert_equal 'dictionaries/fancy-dict.dic', poem_files.dictionary_file
	end

	def test_raises_error_when_given_dictionary_cannot_be_found
		poem_files = Poeta::PoemFiles.new('dsb', 'fancy-dict')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/default_dsb.dic', 'dictionaries/default_dsb.cfg')

		begin
			poem_files.resolve!
			flunk 'Expected to throw an exception'
		rescue => e
			assert_include e.to_s, 'fancy-dict.dic'
		end
	end

	def test_uses_sentences_for_given_dictionary
		poem_files = Poeta::PoemFiles.new('dsb', 'fancy-dict')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/default_dsb.dic', 'dictionaries/default_dsb.cfg',
			'dictionaries/fancy-dict.dic', 'dictionaries/fancy-dict.cfg')

		poem_files.resolve!

		assert_equal 'dictionaries/fancy-dict.cfg', poem_files.sentences_file
	end

	def test_uses_language_sentences_when_dictionary_has_none
		poem_files = Poeta::PoemFiles.new('dsb', 'fancy-dict')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/default_dsb.dic', 'dictionaries/default_dsb.cfg',
			'dictionaries/fancy-dict.dic')

		poem_files.resolve!

		assert_equal 'dictionaries/default_dsb.cfg', poem_files.sentences_file
	end

	def test_raises_error_when_no_sentences_can_be_found
		poem_files = Poeta::PoemFiles.new('dsb', 'fancy-dict')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/fancy-dict.dic')

		begin
			poem_files.resolve!
			flunk 'Expected to throw an exception'
		rescue => e
			assert_include e.to_s, 'default_dsb.cfg'
		end
	end

	def test_uses_dictionary_titles
		poem_files = Poeta::PoemFiles.new('dsb', 'fancy-dict')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/default_dsb.cfg', 'dictionaries/fancy-dict.dic', 'dictionaries/fancy-dict.titles.cfg')

		poem_files.resolve!

		assert_equal 'dictionaries/fancy-dict.titles.cfg', poem_files.title_sentences_file
	end

	def test_uses_language_titles_if_no_dictionary_ones
		poem_files = Poeta::PoemFiles.new('dsb', 'fancy-dict')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/default_dsb.cfg', 'dictionaries/fancy-dict.dic', 'dictionaries/default_dsb.titles.cfg')

		poem_files.resolve!

		assert_equal 'dictionaries/default_dsb.titles.cfg', poem_files.title_sentences_file
	end

	def test_uses_global_titles_if_no_dictionary_and_no_language_ones
		poem_files = Poeta::PoemFiles.new('dsb', 'fancy-dict')
		poem_files.io = @stub_io
		having_existing_files('dictionaries/default_dsb.cfg', 'dictionaries/fancy-dict.dic')

		poem_files.resolve!

		assert_equal 'titles.cfg', poem_files.title_sentences_file
	end

	private

	def having_existing_files(*paths)
		paths.each { |path| @stub_io.stub(:exists?).with(path).and_return(true) }
	end
end
