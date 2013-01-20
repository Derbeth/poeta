module ByFrequencyChoser
	# gets random index in given array based on frequencies.
	# Each element of the array has to respond to 'frequency' message, returning
	# a number.
	def ByFrequencyChoser.choose_random_index(freqs_array)
		sum_freqs = freqs_array.inject(0) {|sum,elem| sum + elem.frequency}
		point = rand sum_freqs
		cur_freq, index, found = 0, 0, -1
		freqs_array.each do |elem|
			if elem.frequency != 0
				cur_freq += elem.frequency
				if cur_freq > point
					found = index
					break
				end
			end
			index += 1
		end
# 		puts "point: #{point} index #{index} sum #{sum_freqs} of #{freqs_array.size}"
		found
	end

	def ByFrequencyChoser.choose_random(freqs_array)
		index = choose_random_index(freqs_array)
		return index == -1 ? nil : freqs_array[index]
	end
end

module ChanceChecker
	def validate_chance(chance)
		raise ArgumentError, "chance should be 0.0 and 1.0, but got #{chance}" if chance < 0.0 || chance > 1.0
	end

	# gets a random number in [0,1) and returns true if it smaller than given chance
	def check_chance(chance)
		draw = rand
		draw < chance
	end
end
