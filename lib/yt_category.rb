class YTCategory
	attr_accessor :label,:term,:lang,:assignable
	
	def initialize(data)
		@label = data[:label]
    @term = data[:term]
    @lang = data[:lang]
    @assignable = data[:assignable]
	end
end