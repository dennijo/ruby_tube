class YTMessage
	attr_accessor :id,:published_at,:updated_at,:title,:author,:video_uri,:message

	def initialize(data)
    @id = data[:id]
		@published_at = data[:published]
    @updated_at = data[:updated]
    @title = data[:title]
    @author = data[:author]
    @video_uri = data[:video_uri]
    @message = data[:content]
	end
end