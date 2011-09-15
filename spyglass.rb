#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'webee'

WeBee::Api.user = ENV['user'] || 'srubio'
WeBee::Api.password = ENV['pass'] || 'srubio'
WeBee::Api.url = 'http://mothership/api'

def require_vendor(lib)
  require File.join(File.dirname(__FILE__), 'vendor', lib)
end

configure do
  set :public, 'public'
  set :views,  'views'
  set :env, :development
  set :port, 3000
end


helpers do

  def multi_cpu_usage(cpus)
    usage = cpus.map do |cpu| 
      "#{cpu.number}: #{"%0.2f" % (cpu.utilisation * 100)}"
    end
    usage.join " "
  end

  def get_cluster
    WeBee::Datacenter.all.first
  end

  def hosts
    machines = []
    datacenter.racks.each do |rack|
      machines += rack.machines
    end
    machines.sort { |h1, h2| h1.name <=> h2.name }
  end

  def humanize_bytes(bytes)
    m = bytes.to_i
    units = %w[Bits Bytes MB GB TB PB]
    while (m/1024.0) >= 1 
      m = m/1024.0
      units.shift
    end
    return m.round.to_s + " #{units[0]}"
  end

  def datacenter
    WeBee::Datacenter.all.first
  end

  def vm_by_name(label)
    datacenter.find_vms_by_name(label).first
  end

  def all_vms
    datacenter.find_vms_by_name('.*')
  end

  def all_vifs
    vifs = []
    all_vms.each do |vm|
      vifs.concat vm.vifs
    end
    vifs
  end

  def top10_cpu_users
    v = all_vms.find_all { |vm| vm.name != 'Domain-0' }
    (v.sort { |a,b| 
      a.metrics.vcpus_utilisation['0'] <=> \
      b.metrics.vcpus_utilisation['0'] }
    ).reverse[0..9]
  end

  def top10_netout_users
    (all_vifs.sort { |a,b| a.metrics.io_write_kbs <=> b.metrics.io_write_kbs }).reverse[0..9]
  end
  def top10_netin_users
    (all_vifs.sort { |a,b| a.metrics.io_read_kbs <=> b.metrics.io_read_kbs }).reverse[0..9]
  end

  def draw_cpu_usage(percentage, color = 'blue')
    Sparklines.plot_to_file("/tmp/sparkline.png", 1.upto(10),
    :type => 'bar',
    :step => 6,
    :upper => percentage * 10 + 1,
    :below_color => color,
    :above_color => 'light gray')
  end

  def partial(template, col)
    buffer = []
    col.each do |m|
        buffer << haml(template,  :layout => false, 
                                  :locals => {template.to_sym => m}
                      )
    end
    buffer.join("\n")
  end

  def host_vbd_graph(host)
    h = host.name.split('.')[0]
    "<img src='/munin/gestion.privada.csic.es/#{h}.gestion.privada.csic.es-xen_vbd-day.png'/>"
  end
  
  def host_cpu_graph(host)
    h = host.name.split('.')[0]
    "<img src='/munin/gestion.privada.csic.es/#{h}.gestion.privada.csic.es-xen_cpu-day.png'/>"
  end
  def host_traffic_graph(host)
    h = host.name.split('.')[0]
    "<img src='/munin/gestion.privada.csic.es/#{h}.gestion.privada.csic.es-xen_traffic_all-day.png'/>"
  end

  def recent_vms_added
    []
  end

end

get '/' do
  @page_title = 'Abiquo Mothership'
  haml :index
end

get '/host/list' do
  @page_title = 'Hosts'
  @hosts = hosts
  haml :host_list
end

get '/host/show/*' do
  @refresh_page = true
  @host = nil
  datacenter.racks.each do |rack|
    @host = rack.machines.find { |m| m.name == params['splat'][0] }
  end
  @page_title = 'Host Overview'
  haml :host_show
end

get '/vm/show/*' do
  @page_title = 'VM Overview'
  @vm = vm_by_name(params['splat'][0])
  haml :vm_show
end

get '/vm/list' do
  @all_vms = all_vms.sort { |a,b| a.name <=> b.name }
  @page_title = 'VM Listing'
  haml :vm_list
end

get '/vm/find' do
  exp = params[:exp]
  puts exp
  @vms = datacenter.find_vms_by_name(exp) 
  @page_title = "VMs matching '#{exp}'"
  haml :vm_find
end

get '/vm/top10_net_users' do
  @page_title = 'Top Network Users'
  @netout = top10_netout_users
  @netin = top10_netin_users
  haml :vm_top10_net_users
end

get '/vm/top10_cpu_users' do
  @page_title = 'Top 10 CPU Users'
  @ttcpu = top10_cpu_users
  haml :vm_top10_cpu_users
end

get '/dashboard' do
  @hosts = hosts
  haml :dashboard
end

get '/vm/recent' do
  @recent_vms = recent_vms_added.reverse
  haml :vm_recent
end

