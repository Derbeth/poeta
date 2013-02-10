# -*- encoding: utf-8 -*-

module Poeta
	# Allows to access results of parsing done by Parser.
	class ParseResult
		def initialize
			@results = []
		end

		# Calls given block with parameters: |opt_name, opt_params|.
		# If the option has no params, opt_params will be nil.
		def each_option
			@results.each { |r| yield r.first, r.last }
		end

		def push_option(name, params=nil)
			@results << [name, params]
		end
	end

	class ParserError < StandardError
	end

	# Parses options of a word or a sentence definition.
	# Each option can take parameters (nesting is allowed). Options are
	# separeted by a configurable separator.
	class Parser
		COMMA = 100
		SPACE = 101

		def initialize(separator=SPACE)
			@separator = separator
		end

		# parses the source
		# returns an instance of ParseResult
		def parse(source)
			result = ParseResult.new
			split_by = case @separator
				when COMMA then /\s*,\s*/
				when SPACE then /\s+/
				else raise ArgumentError, "invalid separator: #@separator"
			end

			escaped = escape(source.strip)

			escaped.split(split_by).each do |part|
				part = unescape_once(part)
				part.strip!
				if part =~ /(\w+)\s*\(([^)]+)\)/
					opt_name = $1
					opt_params = $2

					params = opt_params.strip.split(/\s*,\s*/).map do |param|
						unescape_all(param).strip
					end

					result.push_option(opt_name, params)
				else
					result.push_option(part)
				end
			end
			result
		end

		private

		MAX_NESTING = 5

		def escape(string)
			if string.count('(') != string.count(')')
				raise ParserError, "unbalanced braces in '#{string}'"
			end

			@escaped = []
			last_escaped = -1
			nesting = 0
			while string =~ /\(.*\)/
				string.gsub!(/\w+\s*\([^()]*\)/) do
					|match| last_escaped +=1
					@escaped[last_escaped] = match
					"%ESC#{last_escaped}%"
				end
				nesting += 1
				raise ParserError, "syntax error in '#{string}'" if nesting > MAX_NESTING
			end

			string
		end

		def unescape_all(string)
			nesting = 0
			while string.include?('%ESC')
				string = unescape_once(string)
				nesting += 1
				raise ParserError, "syntax error in '#{string}'" if nesting > MAX_NESTING
			end
			string
		end

		def unescape_once(string)
			string.gsub!(/%ESC(\d+)%/) do
				val = @escaped[$1.to_i]
				raise ParserError, "syntax error, unmatched $1" unless val
				val
			end
			string
		end
	end
end
