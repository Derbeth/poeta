require 'logger'
require 'yaml'

require './randomized_choice'

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

	# Reads configuration from given source (file, stream, string).
	# Returns false if the configuration is in wrong format, true if it is in
	# good format (even if nothing was read).
	def read(source)
		loaded = YAML.load(source)
		return true if loaded == false
		unless loaded.respond_to?(:each_pair)
			source_desc = source.respond_to?(:path) ? source.path : 'unknown source'
			@logger.error "Wrong format of options in #{source_desc}. Expected simple key-value hash in YAML format"
			return false
		end

		loaded.each_pair do |key, value|
			attr_name = key.to_sym
			setter = :"#{key}="
			if !TRANSIENT_ATTRIBUTES.include?(attr_name) && respond_to?(setter)
				begin
					send(setter, value)
				rescue
					@logger.error "Invalid value of option '#{key}' (#{value}): #{$!}"
				end
			else
				@logger.warn "Unknown option '#{key}' (value: '#{value}')"
			end
		end
		true
	end

	# Returns human-readable summary of the configuration
	def summary
		result = {}
		instance_variables().each do |name|
			if name.to_s =~ /^@(.*)_chance$/
				result[$1.to_sym] = self.instance_variable_get(name)
			end
		end
		result.inspect
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

	include ChanceChecker

	TRANSIENT_ATTRIBUTES = [:logger]

end
