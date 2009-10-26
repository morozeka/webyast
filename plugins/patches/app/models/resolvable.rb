#
# Model for resolvables available via package kit
#
require "dbus"
require 'socket'
require 'thread'

require 'exceptions'

class Resolvable

  attr_accessor   :resolvable_id,
                  :kind,
                  :name,
		  :version,
                  :arch,
                  :repo,
                  :summary

private

  #
  # Resolvable.packagekit_connect
  #
  # connect to PackageKit and create Transaction proxy
  #
  # return Array of <transaction proxy>,<packagekit interface>,<transaction 
  #
  # Reference: http://www.packagekit.org/gtk-doc/index.html
  #

  def self.packagekit_connect
    system_bus = DBus::SystemBus.instance
    # connect to PackageKit service via SystemBus
    pk_service = system_bus.service("org.freedesktop.PackageKit")
    
    # Create PackageKit proxy object
    packagekit_proxy = pk_service.object("/org/freedesktop/PackageKit")

    # learn about object
    packagekit_proxy.introspect
    
    # use the (generic) 'PackageKit' interface
    packagekit_iface = packagekit_proxy["org.freedesktop.PackageKit"]
    
    # get transaction id via this interface
    tid = packagekit_iface.GetTid
    
    # retrieve transaction (proxy) object
    transaction_proxy = pk_service.object(tid[0])
    transaction_proxy.introspect
    
    # use the 'Transaction' interface
    transaction_iface = transaction_proxy["org.freedesktop.PackageKit.Transaction"]
    transaction_proxy.default_iface = "org.freedesktop.PackageKit.Transaction"

    [transaction_iface, packagekit_iface]
  end

public

  # default constructor
  def initialize(attributes)
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def id
    @resolvable_id
  end

  def id=(id_val)
    @resolvable_id = id_val
  end

  # get xml representation of instance
  # tag: name of toplevel tag (i.e. :package)
  #
  def to_xml( tag, options = {} )
    xml = options[:builder] ||= Builder::XmlMarkup.new(options)
    xml.instruct! unless options[:skip_instruct]

    xml.tag! tag do
      xml.tag!(:resolvable_id, @resolvable_id, {:type => "integer"} )
      xml.tag!(:kind, @kind )
      xml.tag!(:name, @name )
      xml.tag!(:version, @version )
      xml.tag!(:arch, @arch )
      xml.tag!(:repo, @repo )
      xml.tag!(:summary, @summary )
    end

  end
  
  def to_json( options = {} )
    hash = Hash.from_xml(self.to_xml())
    return hash.to_json
  end

  # returns the modification time of the resolvable
  # which you can use for cache policy purposes
  def self.mtime
    # we look for the most recent (max) modification time
    # of either the package database or libzypp cache files
    [ File.stat("/var/lib/rpm/Packages").mtime,
      File.stat("/var/cache/zypp/solv").mtime,
      * Dir["/var/cache/zypp/solv/*/solv"].map{ |x| File.stat(x).mtime } ].max
  end

  #
  # Execute PackageKit transaction method
  #
  # method: method to execute
  # args: arguments to method
  # signal: signal to intercept (usuallay "Package")
  # block: block to run on signal
  #
  def self.execute(method, args, signal, &block)
    begin
      transaction_iface, packagekit_iface = self.packagekit_connect
    
      proxy = transaction_iface.object
    
      proxy.on_signal(signal.to_s, &block)
      transaction_iface.send(method.to_sym, *args)
    
      dbusloop = DBus::Main.new
      proxy.on_signal("Error") {|u1,u2| dbusloop.quit }
      proxy.on_signal("Finished") {|u1,u2| dbusloop.quit }

      dbusloop << DBus::SystemBus.instance
      dbusloop.run

      packagekit_iface.SuggestDaemonQuit
    rescue DBus::Error => dbus_error
      # check if it is a known error
      raise ServiceNotAvailable.new('PackageKit') if dbus_error.message =~ /org.freedesktop.DBus.Error.ServiceUnknown/
      # otherwise rethrow
      raise dbus_error
    rescue Exception => e
      raise e
    end
  end

  # install an update, based on the PackageKit
  # id ("<name>;<id>;<arch>;<repo>")
  #
  def self.package_kit_install(pk_id)
    ok = true
    transaction_iface, packagekit_iface = self.packagekit_connect

    proxy = transaction_iface.object
    proxy.on_signal("Package") do |line1,line2,line3|
      Rails.logger.debug "  update package: #{line2}"
    end

    dbusloop = DBus::Main.new
    dbusloop << DBus::SystemBus.instance

    proxy.on_signal("Finished") {|u1,u2| dbusloop.quit }
    proxy.on_signal("Error") do |u1,u2|
      ok = false
      dbusloop.quit
    end
    transaction_iface.UpdatePackages([pk_id])

    dbusloop.run
    packagekit_iface.SuggestDaemonQuit

    return ok
  end

  # installs this
  def install
    self.class.install(id)
  end

  # Patch.install(patch)
  # Patch.install(id)
  def self.install(patch)
    if patch.is_a?(Patch)
      update_id = "#{patch.name};#{patch.resolvable_id};#{patch.arch};#{@patch.repo}"
      Rails.logger.debug "Install Update: #{update_id}"
      self.package_kit_install(update_id)
    else
      # if is not an object, assume it is an id
      patch_id = patch
      patch = Patch.find(patch_id)
      raise "Can't install update #{patch_id} because it does not exist" if patch.nil? or not patch.is_a?(Patch)
      self.install(patch)
    end
  end
end
