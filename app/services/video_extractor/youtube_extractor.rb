class VideoExtractor::YoutubeExtractor < VideoExtractor::BaseExtractor
  URL_REGEX = %r{
    (?:
      https?://
      (?:www\.)? youtube\.com/
      .*? (?: &(?:amp;)? | \? )
      v=(?<key>[\w_-]+)
      [^ $#<\[]*
      (?:\#t=(?<time>\d+))?
    ) | (?:
      https?://
      youtu.be/
      (?<key>[\w_-]+)
      (?:\?t=(?<time>\w+))?
    )
  }xi

  def image_url
    "http://img.youtube.com/vi/#{matches[:key]}/mqdefault.jpg"
  end

  def player_url
    "http://youtube.com/embed/#{matches[:key]}" + (matches[:time].present? ? "?start=#{matches[:time]}" : '')
  end

  def matches
    @matches ||= url.match URL_REGEX
  end

  def opengraph_page?
    true
  end

  def exists?
    sleep 1 unless Rails.env.test? # задержка, т.к. ютуб блочит при частых запросах
    open("http://gdata.youtube.com/feeds/api/videos/#{matches[:key]}").read.present?

  rescue OpenURI::HTTPError
    false
  end
end
