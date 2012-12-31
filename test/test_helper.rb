module Grammar
	module TestHelper
		def assert_raise_kind(error,&block)
			yield
			flunk "expected to raise #{error.to_s}"
		rescue
			raise if $!.kind_of?(Test::Unit::AssertionFailedError)
			assert $!.kind_of?(error), "expected #{$!.class} to be kind of #{error}"
		end
	end

	class StubSentenceManager
		def initialize(*sentences)
			raise "should be enumerable" unless sentences.respond_to?(:each)
			@sentence_index=0
			@sentences = []
			sentences.each { |s| self << s }
		end
		def <<(sentence)
			if sentence.is_a? String
				sentence = WithSubjectSentence.new(sentence)
			end
			@sentences << sentence
			self
		end
		def random_sentence
			retval = @sentences[@sentence_index]
			@sentence_index += 1 if @sentence_index < @sentences.size-1
			retval
		end
	end

	class NoSubjectSentence
		def initialize(text='')
			@text = text
		end
		def write
			@text
		end
		def subject
			nil
		end
		def subject=(s)
			# ignore
		end
		def debug_text
			''
		end
	end

	class WithSubjectSentence
		attr_accessor :subject
		def initialize(subject, rest=nil)
			@subject=Noun.new(subject,[],100,MASCULINE)
			@rest=rest
		end
		def write
			text = @subject.text
			text += ' ' + @rest if @rest
			text
		end
		def implicit_subject=(s)
			@subject = s
		end
		def debug_text
			''
		end
	end
end
