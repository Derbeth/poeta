# -*- encoding: utf-8 -*-

require './dictionary'
require './grammar'

class DictionaryStatistics
	# prints the statistics to the standard output
	#
	# possible options: :sort_key (:name, :freq), :sort_order (:asc, :desc)
	def print(dictionary, opts={})
		sort_key = opts[:sort_key] || :name    # :freq
		sort_order = opts[:sort_order] || :asc # :desc
		stats = dictionary.statistics
		stats.each do |speech_part,part_stats|
			puts SpeechParts.describe(speech_part).capitalize + 's:'
			sorted_keys(part_stats, sort_key, sort_order).each do |word|
				word_stats = part_stats[word]
				puts "\t%s\t%s\t%s" % [format_freq(word_stats[:freq]), format_freq(word_stats[:obj_freq]), format_word(word, part_stats)]
			end
		end
	end

	private

	include Grammar

	def sorted_keys(part_stats, sort_key, sort_order)
		result = case sort_key
			when :name then part_stats.keys.sort
			when :freq then part_stats.keys.sort_by { |word| part_stats[word][:freq] }
			else raise "wrong sort key: #{sort_key}"
		end
		case sort_order
			when :asc then result
			when :desc then result.reverse
			else raise "wrong sort order: #{sort_order}"
		end
	end

	def format_freq(freq)
		freq ? ('%5.1f%%' % (freq*100)) : (' '*6)
	end

	def format_word(word, part_stats)
		same_text_words = part_stats.keys.find_all { |other_word| !other_word.equal?(word) && other_word.text == word.text }
		if same_text_words.empty?
			format_word_short(word)
		else
			format_word_verbose(word, same_text_words)
		end
	end

	def format_word_short(word)
		if word.text.empty?
			if word.is_a?(Noun)
				"p=#{word.person}"
			else
				""
			end
		else
			word.text
		end
	end

	def format_word_verbose(word, same_text_words)
		text = format_word_short(word)
		text += "\t" + word_details(word, same_text_words)
		text
	end

	def word_details(word, same_text_words)
		details = []
		if word.is_a? Noun
			details << GENDER2STRING[word.gender] if same_text_words.find { |other| other.gender != word.gender }
			details << 'Pl' if word.number == PLURAL && same_text_words.find { |other| other.number != word.number }
		end
		if word.is_a? Verb
			details << 'REFL' if word.reflexive && same_text_words.find { |other| other.reflexive != word.reflexive }
			word.objects.each { |obj| details << format_gram_object(obj) }
		end
		details << word.get_properties.to_s if !word.get_properties.empty? && same_text_words.find { |other| other.get_properties != word.get_properties }
		details.join(' ')
	end

	def format_gram_object(obj)
		res = obj.to_s
		res.sub('NounObject', 'NOUN').sub('AdjObject', 'ADJ').sub('InfObject', 'INF').sub('()','')
	end
end
