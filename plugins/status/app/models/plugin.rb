#
# This class handles the status of WebYaST plugins
# Each plugin will be checked if it has an REST interface
# "status". This status will be evaluated.
#

require 'yast_service'

class Plugin
  attr_reader :level
  attr_reader :message_id
  attr_reader :short_description
  attr_reader :long_description
  attr_reader :confirmation_host
  attr_reader :confirmation_link
  attr_reader :confirmation_label

  public

  # initialize on element
  def initialize(level, message_id, short_description, 
                 long_description, confirmation_host, 
                 confirmation_link, confirmation_label)
    @level = level
    @message_id = message_id
    @short_description = short_description
    @long_description = long_description
    @confirmation_host = confirmation_host
    @confirmation_link = confirmation_link
    @confirmation_label = confirmation_label
  end

  #
  # find 
  # Plugin.find(:all)
  # Plugin.find(id) 
  # "id" is the plugin name
  #
  def self.find(what)
    models = []
    ret = []
    Resource.all.each {|resource|
      name = resource.controller.split("/").last
      models << (name+"_state").classify if name==what || what==:all
    }
    
    models.each {|model|
      status = Object.const_get(model) rescue $!
      if status.class != NameError && status.respond_to?(:read)
        stat = status.read
        ret << Plugin.new(stat[:level], stat[:message_id], 
                          stat[:short_description], stat[:long_description], 
                          stat[:confirmation_host], stat[:confirmation_link], 
                          stat[:confirmation_label]) unless stat.blank?
      end
    }
    return ret
  end

  # converts the status to xml
  def to_xml(opts={})
    xml = opts[:builder] ||= Builder::XmlMarkup.new(opts)
    xml.instruct! unless opts[:skip_instruct]
    xml.plugin do
      xml.level level
      xml.message_id message_id
      xml.short_description short_description
      xml.long_description long_description
      xml.confirmation_host confirmation_host
      xml.confirmation_link confirmation_link
      xml.confirmation_label confirmation_label
    end
  end

end