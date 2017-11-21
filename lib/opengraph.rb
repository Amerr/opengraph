require 'hashie'
require 'nokogiri'
require 'restclient'

module OpenGraph
  # Fetch Open Graph data from the specified URI. Makes an
  # HTTP GET request and returns an OpenGraph::Object if there
  # is data to be found or <tt>false</tt> if there isn't.
  #
  # Pass <tt>false</tt> for the second argument if you want to
  # see invalid (i.e. missing a required attribute) data.
  def self.fetch(uri, strict = true)
    parse(RestClient.get(uri).body, strict)
  rescue RestClient::Exception, SocketError
    false
  end
  
  def self.parse(html, strict = true)
    doc = Nokogiri::HTML.parse(html)
    page = OpenGraph::Object.new
    doc.css('meta').each do |m|
      if m.attribute('property')
        property = m.attribute('property').to_s
        content = m.attribute('content').to_s
        tag = m.attribute('content').to_s
        if property.match(/^og:(.+)$/i)
          page[$1.gsub('-','_')] = content
        elsif property.match(/^article:(.+)$/i)
          categorize(page, 'article',$1.gsub('-','_'), content)
        elsif property.match(/^book:(.+)$/i)
          categorize(page, 'book',$1.gsub('-','_'), content)
        elsif property.match(/^video:(.+)$/i)
          categorize(page, 'video',$1.gsub('-','_'), content)
        end
      end
    end
    return false if page.keys.empty?
    return false unless page.valid? if strict
    page
  end

  def self.categorize(page, type, key, content)
    page[type] = {} if page[type].nil?
    if page[type][key].nil?
      page[type][key] = content
    else
      page[type][key] = [] unless page[type][key].kind_of?(Array)
      page[type][key] << content
    end
  end

  TYPES = {
    'activity' => %w(activity sport),
    'business' => %w(bar company cafe hotel restaurant),
    'group' => %w(cause sports_league sports_team),
    'organization' => %w(band government non_profit school university),
    'person' => %w(actor athlete author director musician politician public_figure),
    'place' => %w(city country landmark state_province),
    'product' => %w(album book drink food game movie product song tv_show),
    'website' => %w(blog website)
  }
  
  # The OpenGraph::Object is a Hash with method accessors for
  # all detected Open Graph attributes.
  class Object < Hashie::Mash
    MANDATORY_ATTRIBUTES = %w(title type image url)
    
    # The object type.
    def type
      self['type']
    end
    
    # The schema under which this particular object lies. May be any of
    # the keys of the TYPES constant.
    def schema
      OpenGraph::TYPES.each_pair do |schema, types| 
        return schema if types.include?(self.type)
      end
      nil
    end
    
    OpenGraph::TYPES.values.flatten.each do |type|
      define_method "#{type}?" do
        self.type == type
      end
    end
    
    OpenGraph::TYPES.keys.each do |scheme|
      define_method "#{scheme}?" do
        self.type == scheme || OpenGraph::TYPES[scheme].include?(self.type)
      end
    end
    
    # If the Open Graph information for this object doesn't contain
    # the mandatory attributes, this will be <tt>false</tt>.
    def valid?
      MANDATORY_ATTRIBUTES.each{|a| return false unless self[a]}
      true
    end
  end
end