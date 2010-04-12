require File.join(File.dirname(__FILE__), "yt_client.rb")
require File.join(File.dirname(__FILE__), "yt_video.rb")
require File.join(File.dirname(__FILE__), "yt_comment.rb")
require File.join(File.dirname(__FILE__), "yt_rating.rb")
require File.join(File.dirname(__FILE__), "yt_user.rb")
require File.join(File.dirname(__FILE__), "yt_message.rb")
require File.join(File.dirname(__FILE__), "ruby_tube_no_auth.rb")

class RubyTube < YTClient

  def initialize(ctoken, csecret, developer_key,options={})
    super(ctoken,csecret,developer_key,options)
  end
	
	def find(id)
		xml = check_video(id)
		entry = (xml/"entry")
		status = (xml/"yt:state").empty? ? "ok" : (xml/"yt:state").attr("name")
		video = YTVideo.new({
			:id => (entry/"yt:videoid").text,
			:title => (entry/"title").text,
			:description => (entry/"media:description").text,
			:keywords => (entry/"media:keywords").text,
			:duration => (entry/"yt:duration").attr("seconds").to_i,
			:player_uri => (entry/"link[@rel='alternate']").attr("href"),
			:ratings_uri => (entry/"link[@rel$='ratings']").attr("href"),
			:comments_uri => (entry/"gd:comments").search("gd:feedlink").attr("href"),
			:comment_count => (entry/"gd:comments").search("gd:feedlink").attr("countHint").to_i,
			:published_at => Time.parse((entry/"published").text),
			:updated_at => Time.parse((entry/"updated").text),
			:view_count => (entry/"yt:statistics").empty? ? 0 : (entry/"yt:statistics").attr("viewCount"),
			:favorite_count => (entry/"yt:statistics").empty? ? 0 : (entry/"yt:statistics").attr("favoriteCount"),
			:comments => comments((entry/"yt:videoid").text),
			:ratings => ratings((entry/"yt:videoid").text),
			:status => status,
			:thumbnails => process_thumbnail_urls(entry),
		})
		return video
	end

  def status(id)
    xml = check_video(id)
		entry = (xml/"entry")
		status = (xml/"yt:state").empty? ? "ok" : (xml/"yt:state").attr("name")
		video = YTVideo.new({
			:id => (entry/"yt:videoid").text,
			:status => status,
		})
		return video
  end

	def find_all
		@all = all()
		videos = Array.new
		(all/"entry").each do |entry|
			status = (entry/"yt:state").empty? ? "ok" : (entry/"yt:state").attr("name")
      id = (entry/"id").empty? ? (entry/"yt:videoid").text : (entry/"id").text.gsub(/http:\/\/gdata.youtube.com\/feeds\/api\/videos\//,'')
      ratings_uri = (entry/"link[@rel='ratings']").empty? ? '' : (entry/"link[@rel='ratings']").attr("href")
      comments_uri = (entry/"gd:comments").search("gd:feelink").empty? ? (entry/"gd:comments").search("gd:feedLink").attr("href") : (entry/"gd:comments").search("gd:feedlink").attr("href")
      comments_count = (entry/"gd:comments").search("gd:feelink").empty? ? (entry/"gd:comments").search("gd:feedLink").attr("countHint").to_i : (entry/"gd:comments").search("gd:feedlink").attr("countHint").to_i
      comments_allowed = (entry/"yt:accessControl[@action='comment']").empty? ? 'Allowed' : (entry/"yt:accessControl[@action='comment']").attr("permission")
      comment_vote = (entry/"yt:accessControl[@action='commentVote']").empty? ? 'Allowed' : (entry/"yt:accessControl[@action='commentVote']").attr("permission")
      video_respond = (entry/"yt:accessControl[@action='videoRespond']").empty? ? 'Allowed' : (entry/"yt:accessControl[@action='videoRespond']").attr("permission")
      rate = (entry/"yt:accessControl[@action='rate']").empty? ? 'Allowed' : (entry/"yt:accessControl[@action='rate']").attr("permission")
      embed = (entry/"yt:accessControl[@action='embed']").empty ? 'Allowed' : (entry/"yt:accessControl[@action='embed']").attr("permission")
      syndicate = (entry/"yt:accessControl[@action='syndicate']").empty? ? 'Allowed' : (entry/"yt:accessControl[@action='syndicate']").attr("permission")

			video = YTVideo.new({
				:id => id,
				:title => (entry/"title").text,
				:description => (entry/"media:description").text,
				:keywords => (entry/"media:keywords").text,
				:duration => (entry/"yt:duration").attr("seconds").to_i,
				:player_uri => (entry/"link[@rel='alternate']").attr("href"),
				:ratings_uri => ratings_uri,
				:comments_uri => comments_uri,
				:comment_count => comments_count,
				:published_at => Time.parse((entry/"published").text),
				:updated_at => Time.parse((entry/"updated").text),
				:view_count => (entry/"yt:statistics").empty? ? 0 : (entry/"yt:statistics").attr("viewCount"),
				:favorite_count => (entry/"yt:statistics").empty? ? 0 : (entry/"yt:statistics").attr("favoriteCount"),
				:ratings => ratings(id),
				:status => status,
				:thumbnails => process_thumbnail_urls(entry),
        :comments_allowed => comments_allowed,
        :comment_vote => comment_vote,
        :video_respond => video_respond,
        :rate => rate,
        :embed => embed,
        :syndicate => syndicate,
        :published_by => (entry/"author").search("name").text,
        :published_by_uri => (entry/"author").search("uri").text,
        :user => user((entry/"author").search("name").text),
				:comments => get_comments(id)
			})
			videos << video
		end
		return videos
	end

  def get_inbox
    xml = inbox
    msgs = Array.new
		if (xml/"entry").nitems > 0
			(xml/"entry").each do |entry|
        video_info = (entry/"media:group")
				msg = YTMessage.new({
          :id => (entry/"id").text,
					:title => (entry/"title").text,
					:author_uri => (entry/"author").search("uri").text,
          :published => Time.parse((entry/"published").text),
          :updated => Time.parse((entry/"updated").text),
          :author => user((entry/"author").search("name").text),
          :content => (entry/"content").text,
     			:video_uri => (video_info/"media:content").attr("url")
				})
				msgs << msg
			end
		end
    return msgs
  end
  
	def count
		super
	end
	
	def get_comments(id,url=nil)
		xml = comments(id,url)
		comments = Array.new
		if (xml/"entry").nitems > 0
			(xml/"entry").each do |entry|
        in_reply_to = (entry/"link[@rel='http://gdata.youtube.com/schemas/2007#in-reply-to']").empty? ? nil : (entry/"link[@rel='http://gdata.youtube.com/schemas/2007#in-reply-to']").attr("href")
				comment = YTComment.new({
          :id => (entry/"id").text,
					:title => (entry/"title").text,
					:content => (entry/"content").text,
					:author => (entry/"author").search("name").text,
					:author_uri => (entry/"author").search("uri").text,
					:video_uri => (entry/"link[@rel='related']").attr("href"),
          :published_at => Time.parse((entry/"published").text),
          :in_reply_to => in_reply_to
				})
				comments << comment
			end
      unless (xml/"link[@rel='next']").empty?
        next_url = (xml/"link[@rel='next']").attr("href")
        coms = get_comments(id,next_url)
        for com in coms
          comments << com
        end
      end
		end

		return comments
	end
	
	def ratings(id)
		xml = super
		rating = nil
		if xml
			rating = YTRating.new({
				:num_raters => xml.attr("numRaters").to_i,
				:max => xml.attr("max").to_i,
				:min => xml.attr("min").to_i,
				:average => xml.attr("average").to_f
			})
		end
		return rating
	end
	
	def update_video(id, options)
		video = find(id)
		if options[:title]
			video.title = options[:title]
		end
		if options[:description]
			video.description = options[:description]
		end
		if options[:keywords]
			video.keywords = options[:keywords]
		end
		entry = video.to_xml
		response = update(video.id, entry)
		if response.status_code == 200
			return video
		else
			return false
		end
	end

  def get_upload_token(title,description,category,keywords='')
    response = upload_token(title,description,category,keywords)
    if response[:code].to_i == 200
      xml = response[:body]
      upload_token = {:code=>response[:code].to_i,:url=>(xml/"url").text,:token=>(xml/"token").text}
    else
      upload_token = {:code=>response[:code].to_i,:url=>nil,:token=>nil}
    end
    
    return upload_token
  end

	def upload_video(filename, options={})
		response = upload(filename, options)
	end

  def add_comment(id,comment)
    response = add(id,comment)
  end
	
	def delete_video(id)
		response = delete(id)
		if response.status_code == 200
			return true
		else
			return false
		end
	end

  def user(id)
    xml = get_user(id)
    user_info = Array.new
		entry = (xml/"entry")
    if entry.nitems > 0
      user_info = YTUser.new({:username=>(entry/"yt:username").text,
        :title=>(entry/"title").text,
        :gender=>(entry/"yt:gender").text,
        :uri => (entry/"link[@rel='alternate']").attr("href"),
        :location => (entry/"yt:location").text,
				:thumbnails => process_thumbnail_urls(entry)
      })
    end
    return user_info
  end

  def subscriptions(id)
    xml = get_subscriptions(id)
    return xml
  end

  def new_subscription_videos(id)
    xml = get_new_subscription_videos(id)
    videos = Array.new
		(xml/"entry").each do |entry|
			status = (entry/"yt:state").empty? ? "ok" : (entry/"yt:state").attr("name")
			video = YTVideo.new({
				:id => (entry/"yt:videoid").text,
				:title => (entry/"title").text,
				:description => (entry/"media:description").text,
				:player_uri => (entry/"link[@rel='alternate']").attr("href"),
				:published_at => Time.parse((entry/"published").text),
        :comments_allowed => (entry/"yt:accessControl[@action='comment']").attr("permission"),
        :comment_vote => (entry/"yt:accessControl[@action='commentVote']").attr("permission"),
        :video_respond => (entry/"yt:accessControl[@action='videoRespond']").attr("permission"),
        :rate => (entry/"yt:accessControl[@action='rate']").attr("permission"),
        :embed => (entry/"yt:accessControl[@action='embed']").attr("permission"),
        :syndicate => (entry/"yt:accessControl[@action='syndicate']").attr("permission"),
        :published_by => (entry/"author").search("name").text,
        :published_by_uri => (entry/"author").search("uri").text,
				:thumbnails => process_thumbnail_urls(entry),
        :user => user((entry/"author").search("name").text),
				:comments => get_comments((entry/"yt:videoid").text)
			})
			videos << video
		end
    return videos
  end

  def contacts(id)
    xml = get_contacts(id)
    contacts = Array.new
    (xml/"entry").each do |entry|
      contact = (entry/"yt:username").text
      contacts << contact
    end
    return contacts
  end

  def get_categories(id = 'h1=en-US')
    xml = categories(id)
    cats = Array.new
    (xml/"atom:category").each do |entry|
      assignable = (entry/"yt:assignable").empty? ? false : true
      cat = YTCategory.new({
        :label => entry["label"],
        :term => entry["term"],
        :lang => entry["xml:lang"],
        :assignable => assignable,
      })
      cats << cat
    end
    return cats
  end
	
	private
		def process_thumbnail_urls(hpricot)
			thumbs = (hpricot/"media:thumbnail")
			{:big => thumbs.last["url"], :small => thumbs.first["url"]}
		end
	
end