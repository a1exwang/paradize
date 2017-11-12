module Paradize
  class Monitor

  end
  class ScannerMiddleware

  end
  class Scanner
    def determine_file_name(filename)
      filename =~ /([A-Z]+)([-_ ]?)([0-9]+)/
    end
    def determine_file(path)
      filename = File.basename(path)
      file_name_ok = determine_file_name(filename)
      file_format = filename =~ /(avi|mp4|mkv)$/
      file_size = File.size(path) > 100_000_000
      file_name_ok && file_format && file_size
    end
    def determine_data(path)
      if File.directory?(path)
        if determine_file_name(File.basename(path))
          yield true, path
        else
          entries = Dir.entries(path).reject { |x| %w'. ..'.include? x }
          n_vid = entries.map { |x| determine_file(File.join(path, x)) ? 1 : 0 }.reduce(0, &:+)
          n_dir = entries.map { |x| File.directory?(File.join(path, x)) ? 1 : 0 }.reduce(0, &:+)
          if [1, 2].include?(n_vid) && n_dir <= 1
            yield true, path
          else
            yield false, path
          end
        end
      else
        if determine_file path
          yield true, path
        end
      end
    end

    def call_middleware(paths)
      ps, data_ps = [], []
      paths.each do |path|
        determine_data(path) do |type, p|
          if type
            data_ps << p
          else
            ps << p
          end
        end
      end
      [ps, data_ps]
    end
    def call_processor(paths)
      @pipeline.filter(paths)
    end
    def initialize
      @pipeline = ProcessorPipelines.new
    end
    def scan(path)
      stack = [path]
      until stack.empty?
        item = stack.pop
        # puts 'stack: ' + item.inspect
        paths, data_paths = call_middleware([item])
        call_processor(data_paths) unless data_paths.empty?
        paths.each do |current_path|
          do_scan(current_path) do |p1|
            stack.push p1
          end
        end
      end
    end
    private
    def do_scan(path)
      if File.directory?(path)
        Dir.entries(path).each do |filename|
          unless %w'. ..'.include?(filename)
            file_path = File.join(path, filename)
            yield file_path
          end
        end
      end
    end
  end
  class DBPipeline
    def filter(paths)
      paths.each do |path|
        puts '%-80s %-8d' % [path, File.size(path)]
      end
    end
  end
  class ProcessorPipelines
    PIPELINES = [DBPipeline.new]
    def filter(paths)
      data = paths
      PIPELINES.each do |pipeline|
        data = pipeline.filter(data)
      end
      data
    end
  end
end

if ARGV.size > 0
  Paradize::Scanner.new.scan(ARGV[0])
end
