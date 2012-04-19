Puppet::Type.type(:sysctl).provide(:sysctl) do

  confine  :kernel => 'linux'
  commands :sysctl => 'sysctl'

  def exists?
    rvalue = sysctl('-n', resource[:name])
    if rvalue =~ /error: "#{resource[:name]}" is an unknown key/
      return false
    else
      return true
    end
  end

  def self.instances
    self.get_kernelparams
  end

  def self.get_kernelparams
    instances = []
    sysctloutput = sysctl('-a')
    sysctloutput.each do |line|
      #next if line =~ /dev.cdrom.info/
      if line =~ /=/
        kernelsetting = line.split('=')
        instances << new(:name => kernelsetting[0].strip, :value => kernelsetting[1].strip)
      end
    end
    instances
  end

  def destroy
    local_lines = lines
    File.open(resource[:path],'w') do |fh|
      fh.write(local_lines.reject{|l| l =~ /^#{resource[:name]}\s?\=\s?[\S+]/ }.join(''))
    end
    @lines = nil 
  end

  def permanent
    if lines != nil
      lines.find do |line|
        if line =~ /^\s*?#{resource[:name]}/
          return "yes"
        end
      end
    end

    "no"

  end

  def permanent=(ispermanent)
    if ispermanent == "yes"
      a = permanent
      b = ( resource[:value] == nil ? value : resource[:value] )
      if a == "no"
        File.open(resource[:path], 'a') do |fh|
          fh.puts "#{resource[:name]} = #{b}"
        end
#      end
      else
        b = ( resource[:value] == nil ? value : resource[:value] )
        lines.find do |line|
          if line =~ /^\s*?#{resource[:name]}/ && line !~ /^\s*?#{resource[:name]}\s?=\s?#{b}/
            content = File.read(resource[:path])
            File.open(resource[:path],'w') do |fh|
             fh.write(content.gsub(/\n#{resource[:name]}\s?=\s?[\S+]/,"\n#{resource[:name]}\ =\ #{b}"))
            end
          end
        end
      end
    else
      local_lines = lines
      File.open(resource[:path],'w') do |fh|
        fh.write(local_lines.reject{|l| l =~ /^\s*?#{resource[:name]}/ }.join(''))
      end
    end
    @lines = nil
  end

  def value
    thevalue = sysctl('-n', resource[:name])
    kernelvalue = thevalue.strip.gsub(/\s+/," ")
    confvalue = false
    if lines != nil
      lines.find do |line|
        if line =~ /^\s*?#{resource[:name]}/
          thisparam=line.split('=')
          confvalue = thisparam[1].strip
        end
      end
    end

    if confvalue
      if confvalue == kernelvalue
        return kernelvalue
      else
        return "outofsync(kernel:#{kernelvalue},sysctl:#{confvalue})"
      end
    end

    kernelvalue

  end

  def value=(thesetting)
    sysctl('-w', "#{resource[:name]}=#{thesetting}")
    b = ( resource[:value] == nil ? value : resource[:value] )
    lines.find do |line|
      if line =~ /^\s*?#{resource[:name]}/ && line !~ /^\s*?#{resource[:name]}\s*?=\s*?#{b}/
        content = File.read(resource[:path])
        File.open(resource[:path],'w') do |fh|
          # this regex is not perfect yet
          fh.write(content.gsub(/\n#{resource[:name]}\s*?=.+\n/,"\n#{resource[:name]}\ =\ #{b}\n"))
        end
      end
    end
    # fiddyspence
    # we reset @lines here because of caching issues with the way we populate @lines if stuff changes
    @lines = nil
  end

  def lines
    begin
      @lines ||= File.readlines(resource[:path])
    rescue Errno::ENOENT
      return nil
    end
  end
end
