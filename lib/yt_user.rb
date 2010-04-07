class YTUser
	attr_accessor :username,:title,:gender,:uri,:location,:thumbnails
	
	def initialize(data)
		@username = data[:username]
    @title = data[:title]
    @gender = data[:gender]
    @uri = data[:uri]
    @location = data[:location]
    @thumbnails = data[:thumbnails]
	end
end