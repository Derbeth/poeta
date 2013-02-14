# -*- encoding: utf-8 -*-

require './dictionary'

module Grammar
	class SmartRandomDictionary < Dictionary
		def initialize(max_size=DEFAULT_MAX_SIZE)
			super()
			@max_size=max_size
		end

		protected
		DEFAULT_MAX_TRIES = 5
		DEFAULT_MAX_SIZE = 3

		# returns index of random word or -1 if none can be selected
		def get_random_index(freq_array,speech_part)
			@remembered_indices ||= {}
			@remembered_indices[speech_part] ||= []
			index = nil
			DEFAULT_MAX_TRIES.times do
				index = super(freq_array,speech_part)
				break unless @remembered_indices[speech_part].include?(index)
			end
# 			if speech_part == NOUN
# 				rem = @remembered_indices[speech_part].map {|i| @words[speech_part][i].text }.join(',')
# 				puts "chosen #{@words[speech_part][index]}, remembered [#{rem}]"
# 			end
			@remembered_indices[speech_part].push(index)
			@remembered_indices[speech_part].shift if @remembered_indices[speech_part].size > @max_size
			index
		end
	end
end
