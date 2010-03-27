#!/usr/bin/ruby -w

module Grammar
	MASCULINE,FEMININE,NEUTER = 1..3
	GENDERS = [MASCULINE,FEMININE,NEUTER]

	OBJECT_ONLY = 'OO'

	class Noun
		def initialize(text,props,frequency,gender)
			@text,@gender,@props,@frequency = text,gender,props
			raise "invalid gender #{gender}" unless(GENDERS.contains?(gender))
		end

		attr_reader :frequency
	end

	class Verb
		def initialize(text,props,frequency,preposition,object,props)
		end

		attr_reader :frequency
	end

	class Dictionary
		def initialize
			@words = {}
		end

		def get_random(speech_part)
			index = get_random_index(speech_part)
			@words[speech_part][index]
		end

		def read_rules(source)
			source.each_line do |line|
				next if line =~ /^#/ || line !~ /\w/
				speech_part = ''
				unless line =~ /^(\w)\s+/:
					puts "warn: cannot parse line '#{line}'"
					next;
				end
				speech_part = $1

		protected

		def get_random_index(speech_part)
			raise "no word for #{speech_part}" unless(@words.has_key?(speech_part))
			sum_freqs = @words[speech_part].inject {|sum,word| sum + word.frequency}
			point = rand sum_freqs
			cur_freq, index = 0, 0
			@words[speech_part].each do |word|
				cur_freq += word.frequency
				last if cur_freq > point
				index += 1
			end
			index
		end
	end

end
