#!/usr/bin/ruby -w

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
end
