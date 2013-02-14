# -*- encoding: utf-8 -*-

require './dictionary'

module Grammar
	# Useful for tests: user can supply the object with a sequence of indices
	# and they will be returned. If there are no supplied inidices, falls
	# back to default (returning random index).
	class ControlledDictionary < Dictionary
		def initialize
			super
			# hash: word type => collection of indices
			@supplied_indices = {}
		end

		# may be called as:
		#   set_indices(NOUN, [0,1,2])
		#   set_indices(NOUN => [0,1,2], VERB => [0,0,0])
		def set_indices(*args)
			if args.size == 1
				args[0].each_pair do |speech_part, indices|
					set_indices_for(speech_part, indices)
				end
			else
				if args.size != 2
					raise ArgumentError, "expected two args or a hash, got #{args.inspect}"
				end
				set_indices_for(*args)
			end
		end

		protected
		# override
		def get_random_index(freq_array,speech_part)
			indices = @supplied_indices[speech_part]
			if indices.nil? || indices.empty?
				return super(freq_array,speech_part)
			end

			indices.shift
		end

		def set_indices_for(speech_part, indices)
			unless SPEECH_PARTS.include? speech_part
				raise ArgumentError, "no such speech part: #{speech_part}"
			end
			unless indices.respond_to? :shift
				raise ArgumentError, "expected something array-like but received #{indices.class}"
			end
			words_count = @words[speech_part] ? @words[speech_part].size : 0
			if indices.find { |i| i < 0 || i >= words_count }
				raise ArgumentError, "wrong index in #{indices.inspect}: words count is #{words_count}"
			end
			@supplied_indices[speech_part] = indices
		end

	end
end
