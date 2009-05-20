require "scr"

include ApplicationHelper

class UsersController < ApplicationController
  
  before_filter :login_required

  def initialize
    @scr = Scr.instance
  end
  
#--------------------------------------------------------------------------------
#
#local methods
#
#--------------------------------------------------------------------------------


  def get_user_list
     ret = @scr.execute(["/sbin/yast2", "users", "list"])
     lines = ret[:stderr].split "\n"
     @users = []
     lines.each do |s|   
        user = User.new
        user.login_name = s.rstrip
        @users << user
     end
  end

  def get_user (id)
    if @user
      saveKey = @user.sshkey
    else
      saveKey = nil
    end
    ret = @scr.execute(["/sbin/yast2", "users", "show", "username=#{id}"])
    lines = ret[:stderr].split "\n"
    counter = 0
    @user = User.new
    lines.each do |s|   
      if counter+1 <= lines.length
        case s
        when "Full Name:"
          @user.full_name = lines[counter+1].strip
        when "List of Groups:"
          @user.groups = lines[counter+1].strip
        when "Default Group:"
          @user.default_group = lines[counter+1].strip
        when "Home Directory:"
          @user.home_directory = lines[counter+1].strip
        when "Login Shell:"
          @user.login_shell = lines[counter+1].strip
        when "Login Name:"
          @user.login_name = lines[counter+1].strip
        when "UID:"
          @user.uid = lines[counter+1].strip
        end
      end
      counter += 1
    end
    @user.sshkey = saveKey
  end

  def createSSH
    if @user.home_directory.blank?
      save_key = @user.sshkey
      get_user @user.login_name
      @user.sshkey = save_key
    end
    ret = @scr.read(".target.stat", "#{@user.home_directory}/.ssh/authorized_keys")
    if ret.empty?
      logger.debug "Create: #{@user.home_directory}/.ssh/authorized_keys"
      @scr.execute(["/bin/mkdir", "#{@user.home_directory}/.ssh"])      
      @scr.execute(["/bin/chown", "#{@user.login_name}", "#{@user.home_directory}/.ssh"])      
      @scr.execute(["/bin/chmod", "755", "#{@user.home_directory}/.ssh"])
      @scr.execute(["/usr/bin/touch", "#{@user.home_directory}/.ssh/authorized_keys"])      
      @scr.execute(["/bin/chown", "#{@user.login_name}", "#{@user.home_directory}/.ssh/authorized_keys"])      
      @scr.execute(["/bin/chmod", "644", "#{@user.home_directory}/.ssh/authorized_keys"])
    end
    ret = @scr.execute(["echo", "\"#{@user.sshkey}\"", ">>", "#{@user.home_directory}/.ssh/authorized_keys"])
    @error_id = ret[:exit]
    if ret[:exit] != 0
      @error_string = ret[:stderr]
      return false
    else 
      @error_string = ""
      return true
    end
  end

  def udate_user userId
    ok = true

    if not @user.sshkey.blank?
      ok = createSSH
    end

    command = ["/sbin/yast2", "users", "edit"]

    command << "cn=\"#{@user.full_name}\"" if not @user.full_name.blank?
    if not @user.groups.blank?
      grp_string = @user.groups.map { |group| group[:id] }.join(',')
      command << "grouplist=#{grp_string}"
    end
    
    command << "gid=#{@user.default_group}" if not @user.default_group.blank?
    command << "home=#{@user.home_directory}" if not @user.home_directory.blank?
    command << "shell=#{@user.login_shell}" if not @user.login_shell.blank?
    command << "username=#{userId}" if not userId.blank?
    command << "uid=#{@user.uid}" if not @user.uid.blank?
    command << "password=#{@user.password}" if not @user.password.blank?
    command << "ldap_password=#{@user.ldap_password}" if not @user.ldap_password.blank?
    command << "new_uid=#{@user.new_uid}" if not @user.new_uid.blank?
    command << "new_username=#{@user.new_login_name}" if not @user.new_login_name.blank?
    command << "type=#{@user.type}" if not @user.type.blank?
    command << "batchmode"
    ret = @scr.execute(command)
    if ret[:exit] != 0
      ok = false
      @error_id = ret[:exit]
      @error_string = ret[:stderr]
    else
      @error_id = 0
      @error_string = ""
    end
    return ok
  end

  def add_user
    command = ["/sbin/yast2", "users", "add"]
    command << "cn=\"#{@user.full_name}\""  if not @user.full_name.blank?
    if not @user.groups.blank?
      grp_string = @user.groups.map { |group| group[:id] }.join(',')
      command << "grouplist=#{grp_string}"
    end
    command << "gid=#{@user.default_group}" if not @user.default_group.blank?
    command << "home=#{@user.home_directory}" if not @user.home_directory.blank?
    command << "shell=#{@user.login_shell}" if not @user.login_shell.blank?
    command << "username=#{@user.login_name}" if not @user.login_name.blank?
    command << "uid=#{@user.uid}" if not @user.uid.blank?
    command << "password=#{@user.password}" if not @user.password.blank?
    command << "ldap_password=#{@user.ldap_password}" if not @user.ldap_password.blank?
    command << "no_home" if not @user.no_home.blank? and @user.no_home.eql?('true')
    command << "type=#{@user.type}" if not @user.type.blank?
    command << "batchmode"

    ret = @scr.execute(command)

    logger.debug "Command returns: #{ret.inspect}"

    return true if ret[:exit] == 0

    @error_id = ret[:exit]
    @error_string = ret[:stderr]
    return false
  end

  def delete_user
    command = ["/sbin/yast2", "users",  "delete", "delete_home"]
    command << "uid=#{@user.uid}" if not @user.uid.blank?
    command << "username=#{@user.login_name}" if not @user.login_name.blank?
    command << "ldap_password=#{@user.ldap_password}" if not @user.ldap_password.blank?
    command << "type=#{@user.type}" if not @user.type.blank?

    command << "batchmode"

    ret = @scr.execute(command)
    return true if ret[:exit] == 0

    @error_id = ret[:exit]
    @error_string = ret[:stderr]
    return false

  end

#--------------------------------------------------------------------------------
#
# actions
#
#--------------------------------------------------------------------------------

  # GET /users
  # GET /users.xml
  # GET /users.json
  def index
    unless permission_check( "org.opensuse.yast.system.users.read")
      render ErrorResult.error(403, 1, "no permission") and return
    end
    get_user_list
  end

  # GET /users/1
  # GET /users/1.xml
  def show
    unless permission_check( "org.opensuse.yast.system.users.read")
      render ErrorResult.error(403, 1, "no permission") and return
    end
    get_user params[:id]
  end


  # POST /users
  # POST /users.xml
  # POST /users.json
  def create
    unless permission_check( "org.opensuse.yast.system.users.new")
      render ErrorResult.error(403, 1, "no permission") and return
    end

    @user = User.new
    if @user.update_attributes(params[:users])
      add_user
      if @error_id!=0
        render ErrorResult.error(404, @error_id, @error_string) and return
      end
    else
      render ErrorResult.error(404, 2, "wrong parameter") and return
    end
    render :show
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    unless permission_check( "org.opensuse.yast.system.users.write")
      render ErrorResult.error(403, 1, "no permission") and return
    end
    @user = User.new
    if params[:users] && params[:users][:login_name]
       params[:id] = params[:users][:login_name] #for sync only
    end
    get_user params[:id]
    if @user.update_attributes(params[:users])
      udate_user params[:id]
      if @error_id!=0
        render ErrorResult.error(404, @error_id, @error_string) and return
      end
    else
      render ErrorResult.error(404, 2, "wrong parameter") and return
    end
    render :show
  end

  # DELETE /users/1
  # DELETE /users/1.xml
  # DELETE /users/1.json
  def destroy
    unless permission_check( "org.opensuse.yast.system.users.delete")
      render ErrorResult.error(403, 1, "no permission") and return
    end
    get_user params[:id]
    delete_user
    logger.debug "DELETE: #{@user.inspect}"
    if @error_id!=0
      render ErrorResult.error(404, @error_id, @error_string) and return
    else
      render :show
    end
  end

end

