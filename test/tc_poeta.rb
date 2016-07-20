#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
require 'test/unit'

class PoetaIntegratontest < Test::Unit::TestCase
	def test_runs_default_dictionaries
		%w{de en pl}.each do |lang|
			run_and_check "./poeta.rb -l #{lang}", :message => "run language #{lang}"
		end
	end

	def test_runs_nondefault_dictionaries
		dict_dir = File.expand_path('../../dictionaries/', __FILE__)
		assert File.exists?(dict_dir), "exists #{dict_dir}"
		assert File.directory?(dict_dir)

		dicts_to_run = []
		Dir.glob(File.join(dict_dir, '*.dic')).sort.each do |dict_file|
			next unless File.file?(dict_file) && dict_file =~ /\.dic$/
			dict_file = File.basename(dict_file, '.dic')
			next if dict_file =~ /^default_/
			dicts_to_run << dict_file
		end

		assert ! dicts_to_run.empty?
		dicts_to_run.each do |dict_file|
			run_and_check "./poeta.rb #{dict_file}", :message => "run dictionary #{dict_file}"
		end
	end

	def test_fails_on_nonexistent_dictionary
		run_and_check "./poeta.rb a1b2c3", :should_work => false
	end

	private

	def run_and_check(cmd, opts={})
		expect_success = opts.include?(:should_work) ? opts[:should_work] : true
		message = opts[:message] || "running '#{cmd}' failed"
		puts "...#{cmd}"
		output = `#{cmd}`
		if expect_success
			assert_equal 0, $?.to_i, message
			assert_match /\w/, output, message
		else
			assert_not_equal 0, $?.to_i, message
		end
	end
end
