require "uri"
require "net/http"
require "gdata"
require "hpricot"
require "httparty"
require "time"

class YTClient
	attr_accessor :ctoken, :csecret, :developer_key, :token, :client
	include HTTParty
	
	base_uri "http://gdata.youtube.com/feeds/api"
	format :plain
	
	UPLOAD_URI = "http://uploads.gdata.youtube.com/feeds/api/users/default/uploads"

  def initialize(ctoken, csecret, developer_key,options={})
      @ctoken, @csecret, @consumer_options, @developer_key = ctoken, csecret, options,developer_key
  end

  def consumer
    @client = OAuth::Consumer.new(@ctoken,@csecret,{
        :site=>"https://www.google.com",
        :request_token_path=>"/accounts/OAuthGetRequestToken",
        :authorize_path=>"/accounts/OAuthAuthorizeToken",
        :access_token_path=>"/accounts/OAuthGetAccessToken"})
  end

  def request_token(callback)
    @request_token = consumer.get_request_token({:oauth_callback=>"#{callback}"},{:scope=>"http://gdata.youtube.com"})
  end

  def access_token
    @access_token ||= ::OAuth::AccessToken.new(consumer, @atoken, @asecret)
  end

  def authorize_from_request(rtoken, rsecret, verifier_or_pin)
    request_token = OAuth::RequestToken.new(consumer, rtoken, rsecret)
    access_token = request_token.get_access_token(:oauth_verifier => verifier_or_pin)
    @atoken, @asecret = access_token.token, access_token.secret
  end

  def authorize_from_access(atoken, asecret)
    @atoken, @asecret = atoken, asecret
  end

	def all
    @all_vids = Hpricot.XML(access_token.get(self.class.base_uri + "/users/default/uploads").body)
	end
	
	def count
		(@all_vids/"entry").nitems
	end
	
	def check_video(id)
		Hpricot.XML(access_token.get(self.class.base_uri + "/videos/#{id}").body)
	end
	
	def ratings(id)
		response = Hpricot.XML(access_token.get(self.class.base_uri + "/videos/#{id}").body)
		ratings = (response/"gd:rating")
		if ratings.nitems > 0
			return ratings
		else
			return nil
		end
	end
	
	def comments(id,url=nil)
    unless url
      Hpricot.XML(access_token.get(self.class.base_uri + "/videos/#{id}/comments").body)
    else
      Hpricot.XML(access_token.get(url).body)
    end
	end

  def categories(id)
    Hpricot.XML(access_token.get("http://gdata.youtube.com/schemas/2007/categories.cat?"+id).body)
  end
	
	def upload(file, options={})
		upload_uri = URI.parse(UPLOAD_URI)
		binary_data = read_file(file)
		request_data = <<-REQDATA
--bbe873dc
Content-Type: application/atom+xml; charset=utf-8

<?xml version="1.0"?>
<entry xmlns="http://www.w3.org/2005/Atom"
	xmlns:media="http://search.yahoo.com/mrss/"
	xmlns:yt="http://gdata.youtube.com/schemas/2007">
	<media:group>
		<media:title type="plain">#{options[:title]}</media:title>
		<media:description type="plain">
			#{options[:description]}
		</media:description>
		<media:category scheme="http://gdata.youtube.com/schemas/2007/categories.cat">
			People
		</media:category>
		<media:keywords>#{options[:keywords]}</media:keywords>
	</media:group>
</entry>
--bbe873dc
Content-Type: #{options[:content_type]}
Content-Transfer-Encoding: binary

#{binary_data}
--bbe873dc
REQDATA
		http = Net::HTTP.new(upload_uri.host)
		http.read_timeout = 6000
		headers = {
			'GData-Version' => "2",
			'X-GData-Key' => "key=#{@developer_key}",
			'Slug' => File.basename(file),
			'Content-Type' => 'multipart/related; boundary="bbe873dc"',
			'Content-Length' => request_data.length.to_s,
			'Connection' => 'close'
		}
		res = access_token.post(UPLOAD_URI, request_data, headers)
		response = {:code => res.code, :body => Hpricot.XML(res.body)}
		return response
	end

  def add(id,comment)
		comment_uri = self.class.base_uri + "/videos/#{id}/comments"
		request_data = '<?xml version="1.0" encoding="UTF-8"?>
<entry xmlns="http://www.w3.org/2005/Atom"
    xmlns:yt="http://gdata.youtube.com/schemas/2007">
  <content>'+"#{comment}+"+'</content>
</entry>'
		headers = {
			'GData-Version' => "2",
			'Content-Type' => 'application/atom+xml',
			'X-GData-Key' => "key=#{@developer_key}",
			'Content-Length' => comment.length.to_s,
		}
		res = access_token.post(comment_uri, request_data, headers)
		response = {:code => res.code, :body => Hpricot.XML(res.body)}
		return response
  end

  def upload_token(title,description,category,keywords)
    uri = "http://gdata.youtube.com/action/GetUploadToken"
    request_data = '<?xml version="1.0"?>
<entry xmlns="http://www.w3.org/2005/Atom"
  xmlns:media="http://search.yahoo.com/mrss/"
  xmlns:yt="http://gdata.youtube.com/schemas/2007">
  <media:group>
    <media:title type="plain">'+title+'</media:title>
    <media:description type="plain">'+description+'
    </media:description>
    <media:category
      scheme="http://gdata.youtube.com/schemas/2007/categories.cat">'+category+'
    </media:category>
    <media:keywords>'+keywords+'</media:keywords>
  </media:group>
</entry>'
		headers = {
			'GData-Version' => "2",
			'Content-Type' => 'application/atom+xml; charset=UTF-8',
			'X-GData-Key' => "key=#{@developer_key}",
			'Content-Length' => request_data.length.to_s,
		}
		res = access_token.post(uri, request_data, headers)
		response = {:code => res.code, :body => Hpricot.XML(res.body)}
		return response
  end

	def update(id, xml)
		response = access_token.put(self.class.base_uri + "/users/default/uploads/#{id}", xml)
	end
	
	def delete(id)
		response = access_token.delete(self.class.base_uri + "/users/default/uploads/#{id}")
	end

  def get_user(id)
    response = Hpricot.XML(access_token.get(self.class.base_uri + "/users/#{id}").body)
  end

  def get_subscriptions(id)
    response = Hpricot.XML(access_token.get(self.class.base_uri + "/users/#{id}/subscriptions").body)
  end

  def get_new_subscription_videos(id)
    response = Hpricot.XML(access_token.get(self.class.base_uri + "/users/#{id}/newsubscriptionvideos?v=2").body)
  end

  def get_contacts(id)
    response = Hpricot.XML(access_token.get(self.class.base_uri + "/users/#{id}/contacts?v=2").body)
  end

  def inbox
    response = Hpricot.XML(access_token.get(self.class.base_uri + "/users/default/inbox").body)
  end

	private
	def read_file(file)
		contents = File.open(file, "r") {|io| io.read }
		return contents
	end
end