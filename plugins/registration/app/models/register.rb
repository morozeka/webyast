# = Register model
# Provides methods to call the registration in a RESTful environment.
# The main goal is to provide easy access to the registration workflow,
# the caller must interpret the result and maybe call it again with 
# changed values.


# Hash.from_xml converts dashes in keys to underscores
#  by this we can not find out the correct key name (whether it was a dash or an underscore)
#  unfortunately the regcode keys in registration make excessive use of dashes AND underscores
#  that way the information gets lost what key to assign the correct value.
#  So the function "unrename_keys" will be overwritten
module RailsHashFromWithoutConversationKey
   Hash.class_eval do
     def self.unrename_keys(params)
       case params.class.to_s
         when "Hash"
           params.inject({}) do |h,(k,v)|
             h[k.to_s] = unrename_keys(v)
             h
           end
         when "Array"
           params.map { |v| unrename_keys(v) }
         else
           params
         end
     end
   end
end

class Register

  require 'yast_service'

  attr_accessor :registrationserver
  attr_accessor :certificate
  attr_accessor :context
  attr_accessor_with_default :arguments, Hash.new
  attr_reader   :guid

  @reg = ''

  def initialize(hash={})
    # initialize context
    init_context hash
    # read the configuration
    find
  end

  def init_context(hash)
    # set context defaults
    @context = { 'yastcall'     => '1',
                 'norefresh'    => '1',
                 'restoreRepos' => '1',
                 'forcereg'     => '1',
                 'nohwdata'     => '1',
                 'nooptional'   => '1',
                 'debugMode'    => '2',
                 'logfile'      => Paths::REGISTRATION_LOG }
    @context.merge! hash if hash.class == Hash
  end

  def find
    begin
      config = YastService.Call("YSR::getregistrationconfig")
      @registrationserver = config['regserverurl']
      @certificate = config['regserverca']
      @guid = config['guid']
    rescue Exception => e
      Rails.logger.error "YastService.Call('YSR::getregistrationconfig') failed"
      raise
    end
    config
  end

  def register
    # don't know how to pass only one hash, so split it into two. FIXME change later if possible!
    # @reg = YastService.Call("YSR::statelessregister", { 'ctx' => ctx, 'arguments' => args } )

    ctx = Hash.new
    args = Hash.new
    begin
      self.context.each   { |k, v|  ctx[k.to_s] = [ 's', v.to_s ] }
      self.arguments.each { |k, v| args[k.to_s] = [ 's', v.to_s ] }
    rescue
      Rails.logger.error "When registration was called, the context or the arguments data was invalid."
      raise InvalidParameters.new :registrationdata => "Invalid"
    end

    @reg = YastService.Call("YSR::statelessregister", ctx, args )

#    logger.debug "ATREG: #{@reg.inspect}"

    @arguments = Hash.from_xml(@reg['missingarguments']) if @reg && @reg.has_key?('missingarguments')
    @arguments = @arguments["missingarguments"] if @arguments && @arguments.has_key?('missingarguments')

    @reg['exitcode'] rescue 99
  end

  def save
    newconfig = { 'regserverurl' => registrationserver,
                  'regserverca'  => certificate  }
    ret = YastService.Call("YSR::setregistrationconfig", newconfig)

    self.find
    return ret
  end

  def status_to_xml( options = {} )
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]

    xml.registration do
      xml.guid @guid if @guid && @guid.size > 0
    end
  end

  def config_to_xml( options = {} )
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]

    xml.registrationconfig do
      xml.server do
        xml.url @registrationserver if @registrationserver
      end
     xml.certificate do
       xml.data do
         xml.cdata!(@certificate) if @certificate && @certificate.size > 0
       end
     end
    end
  end

  def to_xml( options = {} )
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]

    status = if !@reg ||  @reg['error'] then  'error'
             elsif @reg['missinginfo']  then  'missinginfo'
             elsif @reg['success']      then  'finished'
             end

    tasklist = Hash.from_xml @reg['tasklist'] if @reg && @reg['tasklist']
    if tasklist
      tasklist = tasklist['tasklist'] if tasklist.has_key? 'tasklist'
      changedrepos    = tasklist.reject { | k, v |  v.class != Hash || v['type'] != 'zypp'  }
      changedservices = tasklist.reject { | k, v |  v.class != Hash || v['type'] != 'nu'  }
    else
      changedrepos = {}
      changedservices = {}
    end
    tasknic = { 'a'  => 'added',         'd' => 'deleted',
                'le' => 'leave enabled', 'ld' => 'leave disabled'}

    xml.registration do
      if @reg 
        xml.status status
        xml.exitcode @reg['exitcode'] || ''
        xml.guid @reg['guid'] || ''

        if @arguments
          xml.missingarguments({:type => "array"}) do
            @arguments.each do | k, v |
              if k && v.class == Hash
                xml.argument do
                  xml.name k
                  xml.value v['value']
                  xml.flag v['flag']
                  xml.kind v['kind']
                  xml.type 'string'
                end
              end
            end
          end
        end

        if changedrepos
          xml.changedrepos({:type => "array"}) do
            changedrepos.each do | k, v |
              if k && v.class == Hash && v["task"] != "le" && v["task"] != "ld" #only changed repos
                xml.repo do
                  xml.name k
                  xml.alias v['alias'] || ''
                  xml.type v['type']  || ''
                  xml.url v['url'] || ''
                  xml.status tasknic[ v['task'] ] || ''
                end
              end
            end
          end
        end

        if changedservices
          xml.changedservices({:type => "array"}) do
            changedservices.each do | k, v |
              if k && v.class == Hash && v["task"] != "le" && v["task"] != "ld" #only changed services
                xml.service do
                  xml.name k
                  xml.alias v['alias'] || ''
                  xml.type v['type']  || ''
                  xml.url v['url'] || ''
                  xml.status tasknic[ v['task'] ] || ''
#disabled. it returns currently only a hash and not a hash in hash
#                  if v['catalogs'] && v['catalogs'].class == Hash
#                    xml.catalogs do
#                      v['catalogs'].each do |l, w|
#                        if l && w.class == Hash
#                          xml.catalog do
#                            xml.name v['NAME'] || ''
#                            xml.alias v['ALIAS'] || ''
#                            xml.status tasknic[ v['TASK'] ] || ''
#                          end
#                        end
#                      end
#                    end
#                  end # catalogs
                end
              end
            end # services.each
          end
        end # changedservices
      else
        xml.tag!(:status, 'error')
        xml.tag!(:exitcode, 1)
      end # if reg
    end # xml-root
  end # func

  def status_to_json( options = {} )
    hash = Hash.from_xml(status_to_xml())
    return hash.to_json
  end

  def config_to_json( options = {} )
    hash = Hash.from_xml(config_to_xml())
    return hash.to_json
  end

  def to_json( options = {} )
    hash = Hash.from_xml(to_xml())
    return hash.to_json
  end


end
