$LOAD_PATH << File.dirname(__FILE__)

unless defined? SKETCH_PATH
  SKETCH_PATH = ARGV.shift
  SKETCH_ROOT = File.dirname(SKETCH_PATH)
  $LOAD_PATH << SKETCH_ROOT
end

module Processing
  CONFIG = {}
end

def get_class_paths(str)
  # Assumes that the string has separator on the top.
  # ex. ':/Applications/Processing.app/Contents/Java/core/library/core.jar:/Applications/...'
  separator = str[0]
  str[1..-1].split(separator)
end

unless Processing::CONFIG.has_key?('PROCESSING_ROOT')
  Processing::CONFIG['PROCESSING_ROOT'] = ARGV.shift
end

require 'ruby-processing/helpers/string'
require 'ruby-processing/helpers/numeric'
require 'ruby-processing/app'

module Processing
  def self.exported?
    false
  end

  def self.load_and_run_sketch(options={})
    source = self.read_sketch_source
    has_sketch = !!source.match(/^[^#]*< Processing::App/)
    has_methods = !!source.match(/^[^#]*(def\s+setup|def\s+draw)/)
    has_settings = !!source.match(/^[^#]*(def\s+settings)/)

    loads = Dir.glob("#{SKETCH_ROOT}/*.rb").map do |path|
      "load '#{File.basename(path)}'"
    end.join("\n")

    if has_sketch
      load SKETCH_PATH
      Processing::App.sketch_class.new if !$app
    else
      # For use with "bare" sketches that don't want to define a class or methods

      size_call, source = extract_size_call(source)
      if size_call
        if has_settings
          source = inject_size_call_to_settings(source, size_call)
        else
          settings = "def settings; #{size_call}; end"
        end
      end

      if has_methods
        code = <<-EOS
          #{loads}
          class Sketch < Processing::App
            #{settings}
            #{source}
          end
        EOS
      else
        code = <<-EOS
          #{loads}
          class Sketch < Processing::App
            #{settings}
            def setup
              #{source}
              no_loop
            end
          end
        EOS
      end
      begin
        Object.class_eval(code, SKETCH_PATH, -1)
        #Processing::App.sketch_class.new  # sketch_class doesn't exist.
        sketch = Sketch.new(options)
      rescue Exception => exc
        $stderr.print(exc.to_s)
      end
    end
  end

  # Read in the sketch source code. Needs to work both online and offline.
  def self.read_sketch_source
    File.read(SKETCH_PATH)
  end

  def self.restart_sketch(options)
    if $app
      $app.close
      $app = nil
    end
    load_and_run_sketch(options)
  end

  def self.extract_size_call(code)
    unless code =~ /^(\s*size[\s\(].*)[\n\Z]/
      return nil, code
    end

    size_call = $1
    before = $`
    after = $'
    return size_call, "#{before}#{after}"
  end

  def self.inject_size_call_to_settings(code, size_call)
    unless code =~ /^([^#]*def\s*settings(\n|\W.*?\n))/
      return code
    end

    settings_def = $1
    before = $`
    after = $'
    return "#{before}#{settings_def}#{size_call}\n#{after}"
  end
end

# Thread to handle messages from PDE.
t = Thread.new do
  while $stdin.gets
    case $_.chomp
    when 'close'
      if $app
        $app.close
        $app = nil
      end
    when /^requestRestart\?(.*)$/  # Restart request
      options = $1.split('&').inject({}) {|h, e| k, v = e.split('=', 2); h[k.intern] = v; h}
      Processing.restart_sketch(options)
    end
  end
end

Processing.load_and_run_sketch

t.join
