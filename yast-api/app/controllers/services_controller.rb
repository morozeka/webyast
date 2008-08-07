class ServicesController < ApplicationController
  private
  def init_services
    services = Hash.new
    Lsbservice.all.each do |d|
      begin
        service = Lsbservice.new d
        services[service.name] = service
      rescue # Don't fail on non-existing service. Should be more specific.
      end
    end
    session['services'] = services
  end
  def respond data
    STDERR.puts "Respond #{data.class}"
    if data
      respond_to do |format|
	format.xml do
	  render :xml => data.to_xml
	end
	format.json do
	  render :json => data.to_json
	end
	format.html do
	  render
	end
      end
    else
      render :nothing => true, :status => 404 unless @service # not found
    end
  end
  public
  def index
    init_services unless session['services']
    @services ||= session['services']
    respond @services
  end
  def show
    id = params[:id]
    @service = Service.new
    @service.name = id
    @service.commands = "commands"
    @service.configs = "configs"
    respond_to do |format|
      format.xml do
        render :xml => @service.to_xml( :root => "services",
          :dasherize => false )
      end
      format.json do
        render :json => @service.to_json
      end
      format.html do
        respond @service
      end
    end
  end
end
