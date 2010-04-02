# class Repository represents a software repository

require 'packagekit'

class Repository < BaseModel::Base

  attr_accessor   :id,
    :name,
    :enabled,
    :autorefresh,
    :url,
    :priority,
    :keep_packages

   # alias and URL must not be empty on save
   validates_presence_of :id
   validates_presence_of :url
   # check for boolean flags
   validates_inclusion_of :enabled, :in => [true, false]
   validates_inclusion_of :autorefresh, :in => [true, false]
   validates_inclusion_of :keep_packages, :in => [true, false]
   # priority must be in range 0..200
   validates_inclusion_of :priority, :in => 0..200


  def initialize(id, name, enabled)
    @id = id
    @name = name
    @enabled = enabled

    # set defaults
    @url = ''
    @priority = 99
    @autorefresh = true
    @keep_packages = false
  end

  def self.find(what)
    repositories = Array.new

    PackageKit.transact('GetRepoList', 'NONE', 'RepoDetail') { |id, name, enabled|
      Rails.logger.debug "RepoDetail signal received: #{id}, #{name}, #{enabled}"

      if what == :all || id == what
        repo = Repository.new(id, name, enabled)
        # read other attributes directly from *.repo file,
        # because PackageKit doesn't have API for that
        repo.read_file

        repositories << repo
      end
    }

    repositories
  end

  def self.mtime
    [ File.stat("/etc/zypp/repos.d").mtime,
      * Dir["/etc/zypp/repos.d/*.repo"].map{ |x| File.stat(x).mtime } ].max
  end

  # read autorefresh, URL, keep_packages and priority directly from *.repo file
  def read_file
    fname = "/etc/zypp/repos.d/#{@id}.repo"
    Rails.logger.debug "Reading repofile: #{fname}"

    read_from_file fname
  end

  def read_from_file fname
    return unless File.readable? fname

    File.open(fname) do |file|

      while line = file.gets
	# remove comments
	line.match /^([^#]*)#*.*$/
	l = $1

	next if l.blank?

	l.match /^[ \t]*([^= \t]*)[ \t]*=[ \t]*(.*)[ \t]*$/

	key = $1
	next if key.blank?
	value = $2
	next if value.blank?

	Rails.logger.debug "Read key: #{key}, value: #{value}"

	case key
	when 'autorefresh'
	  @autorefresh = (value == 'true' || value == '1')
	when 'keeppackages'
	  @keep_packages = (value == 'true' || value == '1')
	when 'priority'
	  if value.match /[0-9]+/
	    @priority = value.to_i
	  else
	    Rails.logger.error "Non-number value for priority key: #{value}"
	  end
	when 'baseurl'
	  @url = value
	  # other values are returned by PackageKit, just ignore them
	end

      end # while
    end # File.open
  end

  private :read_from_file

  #
  #
  #
  def self.exists?(id)
    self.find(:all).any? do |repo|
      return true if repo.id == id
    end
    false
  end

  #
  #
  #
  def update
    # create a new repository if it does not exist yet
    if !Repository.exists?(@id)
      Rails.logger.info "Adding a new repository '#{@id}': #{self.inspect}"
      PackageKit.transact('RepoSetData', [@id, 'add', @url])
    else
      Rails.logger.info "Modifying repository '#{@id}': #{self.inspect}"
      # set url
      PackageKit.transact('RepoSetData', [@id, 'url', @url])
    end

    # set enabled flag
    PackageKit.transact('RepoEnable', [@id, @enabled])

    # set priority
    PackageKit.transact('RepoSetData', [@id, 'prio', @priority.to_s])

    # set autorefresh
    PackageKit.transact('RepoSetData', [@id, 'refresh', @autorefresh.to_s])

    # set name
    PackageKit.transact('RepoSetData', [@id, 'name', @name.to_s])

    # set keep_package
    PackageKit.transact('RepoSetData', [@id, 'keep', @keep_packages.to_s])
  end

  #
  #
  #
  def destroy
    return false if @id.blank?

    PackageKit.transact('RepoSetData', [@id, 'remove', 'NONE'])
  end


end
