class PoetryConfiguration
	attr_accessor :implicit_subject_chance
	attr_accessor :verses_number
	attr_accessor :lines_in_verse
	attr_accessor :max_line_length

	def initialize
		@implicit_subject_chance = 0.25
		@verses_number = 4
		@lines_in_verse = 4
		@max_line_length = 52
	end
end
