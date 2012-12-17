require 'logger'

class PoetryConfiguration
	attr_accessor :verses_number
	attr_accessor :lines_in_verse
	attr_accessor :max_line_length
	attr_reader :debug
	attr_reader :implicit_subject_chance
	attr_reader :double_adj_chance
	attr_reader :double_noun_chance
	attr_reader :other_word_chance
	attr_reader :object_adj_chance

	def initialize
		@verses_number = 4
		@lines_in_verse = 4
		@max_line_length = 52

		@implicit_subject_chance = 0.25
		@other_word_chance = 0.3
		@double_adj_chance = 0.3
		@double_noun_chance = 0.2
		@object_adj_chance = 0.3

		@logger = Logger.new(STDERR)
		@logger.formatter = proc do |severity, datetime, progname, msg|
			"#{msg}\n"
		end
		self.debug = false
	end

	def debug=(val)
		@debug = val
		@logger.level = @debug ? Logger::DEBUG : Logger::WARN
	end

	def logger
		@logger
	end

	def implicit_subject_chance=(chance)
		validate_chance(chance)
		@implicit_subject_chance = chance
	end

	def other_word_chance=(chance)
		validate_chance(chance)
		@other_word_chance = chance
	end

	def double_adj_chance=(chance)
		validate_chance(chance)
		@double_adj_chance = chance
	end

	def double_noun_chance=(chance)
		validate_chance(chance)
		@double_noun_chance = chance
	end

	def object_adj_chance=(chance)
		validate_chance(chance)
		@object_adj_chance = chance
	end

	private

	def validate_chance(chance)
		raise ArgumentError, "chance should be 0.0 and 1.0, but got #{chance}" if chance < 0.0 || chance > 1.0
	end

end
