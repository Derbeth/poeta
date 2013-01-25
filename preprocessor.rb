# -*- encoding: utf-8 -*-

require './randomized_choice'

module Poeta
	# preprocessor accepting a subset of commands known to C preprocessor
	class Preprocessor
		def initialize(conf)
			@conf = conf
			@vars = {}
			@functions = {'CHANCE' => lambda { |chance| ch = chance.to_f ; validate_chance(ch) ; check_chance(ch) ? 1 : 0 } }
		end

		# Returns processed source.
		# Output should be iterated with each_line method.
		# After processing one source, the processor instance will remember
		# all defined variables when called to process an another source.
		def process(source)
			@source = source.respond_to?(:path) ? File.basename(source.path) : 'unknown'
			@line_no = 0
			@last_if = nil
			@outputting = true
			out_lines = []
			source.each_line do |line|
				@line_no += 1
				if is_from_preprocessor?(line)
					parse(line)
				else
					if @outputting
						out_lines << line
					end
				end
			end
			if @last_if
				raise PreprocessorError, "#@source:#@last_if:error: unmatched #if"
			end
			FakeIO.new(out_lines)
		end

		def set_function(name, func)
			@functions[name] = func
		end

		private

		include ChanceChecker

		def is_from_preprocessor?(line)
			line =~ /^#(define|if|else|endif)\b/
		end

		def parse(line)
			line.chomp!
			accepted = false
			case line
				when /^#define\s+(\w+)\s+(.+)/
					accepted = handle_definition($1, $2)
				when /#if\s+(\w+)/
					handle_if($1)
					accepted = true
				when /#else\s*$/
					handle_else
					accepted = true
				when /#endif\s*$/
					handle_endif
					accepted = true
				else
					@conf.logger.error "#@source:#@line_no:warn: preprocessor cannot handle command '#{line}'"
			end
			accepted
		end

		def handle_definition(name, body)
			return unless @outputting

			if body =~ /^(\d+)$/
				@vars[name] = $1.to_i
				@conf.logger.debug "preprocessor: defined #{name} as #{@vars[name]}"
				true
			elsif body =~ /^\s*(\w+)\s*\(([^)]+)\)\s*$/
				func_name = $1
				unless @functions.include?(func_name)
					@conf.logger.error "#@source:#@line_no:error: preprocessor: no function with name '#{func_name}'"
					return false
				end
				args = $2.split(',').map { |s| s.strip }
				begin
					@vars[name] = @functions[func_name].call(*args)
					@conf.logger.debug "preprocessor: defined #{name} as #{@vars[name]}"
					true
				rescue
					@conf.logger.error "#@source:#@line_no:error: invalid call: '#{body}'; reason: #{$!}"
					false
				end
			else
				@conf.logger.error "#@source:#@line_no:error: preprocessor: cannot define variable with value '#{body}'"
				false
			end
		end

		def handle_if(name)
			@last_if = @line_no
			if ! @vars.include?(name)
				@conf.logger.warn "#@source:#@line_no:warn: preprocessor: using undefined '#{name}'"
				@outputting = false
			elsif @vars[name] == 0
				@outputting = false
			else
				@outputting = true
			end
		end

		def handle_else
			unless @last_if
				raise PreprocessorError, "#@source:#@line_no:error: 'else' without 'if'"
			end
			@outputting = ! @outputting
		end

		def handle_endif
			unless @last_if
				raise PreprocessorError, "#@source:#@line_no:error: 'endif' without 'if'"
			end
			@last_if = nil
			@outputting = true
		end

		class FakeIO
			def initialize(lines)
				@lines = lines
			end

			def each_line
				@lines.each { |l| yield l }
			end
		end
	end

	class PreprocessorError < StandardError
	end
end
