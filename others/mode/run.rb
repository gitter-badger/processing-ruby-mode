$LOAD_PATH << File.dirname(__FILE__)

SKETCH_PATH = ARGV.shift unless defined? SKETCH_PATH
SKETCH_ROOT = File.dirname(SKETCH_PATH) unless defined? SKETCH_ROOT

require 'ruby-processing/helpers/string'
require 'ruby-processing/helpers/numeric'
require 'ruby-processing/app'

module Processing
  def self.load_and_run_sketch
    source = self.read_sketch_source
    has_sketch = !!source.match(/^[^#]*< Processing::App/)
    has_methods = !!source.match(/^[^#]*(def\s+setup|def\s+draw)/)

    if has_sketch
      load File.join(SKETCH_ROOT, SKETCH_PATH)
      Processing::App.sketch_class.new if !$app
    else
      # For use with "bare" sketches that don't want to define a class or methods
      if has_methods
        code = <<-EOS
          class Sketch < Processing::App
            #{source}
          end
        EOS
      else
        code = <<-EOS
          class Sketch < Processing::App
            def setup
              size(DEFAULT_WIDTH, DEFAULT_HEIGHT, JAVA2D)
              #{source}
              no_loop
            end
          end
        EOS
      end
      Object.class_eval code, SKETCH_PATH, -1
      Processing::App.sketch_class.new
    end
  end

  # Read in the sketch source code. Needs to work both online and offline.
  def self.read_sketch_source
    File.read(SKETCH_PATH)
  end
end

Processing.load_and_run_sketch