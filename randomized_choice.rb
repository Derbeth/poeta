#!/usr/bin/ruby -w

module ByFrequencyChoser
	def ByFrequencyChoser.choose_random_index(freqs_array)
		sum_freqs = freqs_array.inject(0) {|sum,elem| sum + elem.frequency}
		point = rand sum_freqs
		cur_freq, index, found = 0, 0, -1
		freqs_array.each do |elem|
			if elem.frequency != 0:
				cur_freq += elem.frequency
				if cur_freq > point:
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
