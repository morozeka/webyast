#
# Wrapper over collectd
#
class Status
  require 'scr'
  require 'yaml'

  attr_accessor :data,
                :health_status,
                :metrics
  
  def initialize()
    @scr = Scr.instance
    @health_status = nil
    @data = Hash.new
    # force initialization of datapath
    datapath
    start_collectd

    #find the correct plugin path for the config file
    plugin_config_dir = "#{RAILS_ROOT}/config" #default
    Rails.configuration.plugin_paths.each do |plugin_path|
      if File.directory?(File.join(plugin_path, "status"))
        plugin_config_dir = plugin_path+"/status/config"
        Dir.mkdir(plugin_config_dir) unless File.directory?(plugin_config_dir)
        break
      end
    end
    @limits = {}
    @limits = YAML.load(File.open(File.join(plugin_config_dir, "status_limits.yaml"))) if File.exists?(File.join(plugin_config_dir, "status_limits.yaml"))
  end

  # returns the data path
  def datapath
    if @datapath.blank?
      # if no datapath is set, use the first directory in /var/lib/collectd
      @datapath = Dir.glob("/var/lib/collectd/*").first
    end
    @datapath
  end
  
  # set path of stored rrd files, default: /var/lib/collectd/$host.$domain
  def datapath=(path=nil)
    @datapath = path.chomp("/")
  end
  
  def start_collectd
    cmd = @scr.execute(["/usr/sbin/collectd"])
    @timestamp = Time.now
  end

  def stop_collectd
    cmd = @scr.execute(["killall", "collectd"])
    @timestamp = nil
  end

  # returns available metric types, which are the directories in the
  # data path.
  # requires datapath to be configured
  # ie: ['cpu', 'memory']
  def metric_types
    Dir.glob(File.join(datapath,"*")).reject{|x| not File.directory?(x) }.map{|x| File.basename(x) }
  end

  # returns the full path of metric databases for a metric type
  # ie: /var/foo/cpu/file.rrd
  def metric_files(metrictype)
    Dir.glob(File.join(datapath, metrictype, "*.rrd"))
  end
    
  # creates a hash from metric type (cpu, etc) to
  def available_metrics
    metrics = Hash.new
    # look in datapath, except for non directories, and get the last
    # component of the path ie: interface, cpu, etc
    metric_types.each do |metrictype|
      rrds = Array.new
      metric_files(metrictype).each do |rrdfile|
        rrds << rrdfile
        #puts "#{rrdfile} at #{metrictype}"
      end
      metrics["#{metrictype}"] = { :rrds => rrds}
    end
    metrics
  end

  def determine_status
  end

  def draw_graph(heigth=nil, width=nil)
  end

  # creates several metrics for a defined period
  def collect_data(start=nil, stop=nil, data = %w{cpu memory disk})
    metrics = available_metrics
    result = Hash.new
    unless @timestamp.nil? # collectd not started
        case data
        when nil, "all", "All" # all metrics
          metrics.each_pair do |m, n|
            metrics[m][:rrds].each do |rrdb|
              result[File.basename(rrdb).chomp('.rrd')] = fetch_metric(rrdb, start, stop)
            end
            @data[m] = result
            result = Hash.new
          end
        else # only metrics in data
          data.each do |d|
            metrics.each_pair do |m, n|
              if m.include?(d)
                metrics[m][:rrds].each do |rrdb|
                result[File.basename(rrdb).chomp('.rrd')] = fetch_metric(rrdb, start, stop)
              end
              @data[m] = result
              result = Hash.new
            end
          end
        end
      end
    end
    return @data
  end

  # runs the rddtool on file with start time and end time
  # default last 5 minutes from now
  def run_rrdtool(file, start, stop)
    stop = Time.now if stop.nil?
    # fetch last 5 minutes
    start = stop - 300 if start.nil?

    cmd = IO.popen("rrdtool fetch #{file} AVERAGE --start #{start.strftime("%H:%M,%m/%d/%Y")} --end #{stop.strftime("%H:%M,%m/%d/%Y")}")
    output = cmd.read
    cmd.close
    output
  end
  
  # creates one metric for defined period
  # parameters are the file to read and the
  # time interval
  #
  # If no time is given, last 5 minutes are used
  def fetch_metric(rrdfile, start=nil, stop=nil)
    result = Hash.new
    output = run_rrdtool(rrdfile, start, stop)

    raise "Error running collectd rrdtool" if output =~ /ERROR/ or output.nil?

    labels=""
    output = output.gsub(",", ".") # translates eg. 1,234e+07 to 1.234e+07
    lines = output.split "\n"

    # set label names
    lines[0].each do |l|
      if l =~ /\D*/
        labels = l.split " "
      end
    end
    unless labels.blank?
      # set values for each label and time
      lines.each do |l| # each time
        unless l.blank?
          if l =~ /\d*:\D*/
            pair = l.split ":"
            values = pair[1].split " "
            column = 0
            values.each do |v| # each label
              if v != "nan" #store valid values only
                result["#{labels[column]}"] ||= Hash.new
                result["#{labels[column]}"].merge!({"T_#{pair[0].chomp(": ")}" => v})
                column += 1
              end
            end
          end
        end
      end

      #setting the limits
      result.each do |key, value|        
        path = rrdfile[datapath.length+1..rrdfile.length-1].chomp('.rrd')
        path +="/" + key if key!="value" #do not take care about the value flag
        path = path.tr('-','_')
        if @limits.has_key?(path)
          result[key] ||= Hash.new
          result[key].merge!({"limit" => @limits[path] })
        end
      end
      return result
    else
      raise "error reading data from rrdtool"
    end
  end
end