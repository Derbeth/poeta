# -*- encoding: utf-8 -*-

module Poeta
	# preprocessor accepting a subset of commands known to C preprocessor
	class Preprocessor
		def initialize
			@vars = {}
		end

		# Returns processed source.
		# Output should be iterated with each_line method.
		# After processing one source, the processor instance will remember
		# all defined variables when called to process an another source.
		def process(source)
			@line_no = 0
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
			FakeIO.new(out_lines)
		end

		def set_function(name, func)
		end

		private

		def is_from_preprocessor?(line)
			line =~ /^#(define|if|else|endif)\b/
		end

		def parse(line)
			accepted = false
			case line
				when /^#define\s+(\w+)\s+(.+)/
					accepted = handle_definition($1, $2)
				when /#if\s+(\w+)/
					handle_if($1)
					accepted = true
				when /#else\s+$/
					handle_else
					accepted = true
				when /#endif\s+$/
					handle_endif
					accepted = true
				else
					puts "warn: preprocessor cannot handle command '#{line}'"
			end
			accepted
		end

		def handle_definition(name, body)
			if body =~ /^(\d+)$/
				@vars[name] = $1.to_i
				true
			else
				puts "preprocessor: cannot define variable with value '#{body}'"
				false
			end
		end

		def handle_if(name)
			if @vars.include?(name) && @vars[name] != 0
				@outputting = true
			else
				@outputting = false
			end
		end

		def handle_else
			@outputting = ! @outputting
		end

		def handle_endif
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
end
