class PoetryConfiguration
	attr_accessor :implicit_subject_chance
	attr_accessor :verses_number
	attr_accessor :lines_in_verse

	def initialize
		@implicit_subject_chance = 0.25
		@verses_number = 4
		@lines_in_verse = 4
	end
end
