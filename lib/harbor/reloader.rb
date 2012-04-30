class Harbor
  class Reloader
    attr_accessor :cooldown

    FILES = Hash.new do |hash, file|
      hash[file] = ReloadableFile.new(file)
    end

    def initialize(cooldown = 1)
      @cooldown   = cooldown
      @last       = (Time.now - cooldown)
    end

    def enable!
      Dispatcher::register_event_handler(:begin_request) do
        # Populates FILES with initial mtimes
        Dir[*paths].each { |file| FILES[file] }
        perform
      end
    end

    def perform
      if @cooldown && Time.now > @last + @cooldown
        Thread.list.size > 1 ? Thread.exclusive { reload! } : reload!
        @last = Time.now
      end
    end

    def reload!
      with_reloadable_files do |file|
        if file.required?
          if file.updated?
            file.remove_constant if file.controller_file?
            file.reload
            file.update
          end
        else
          # Always reload code that has been changed but not required yet, it
          # will eventually be required anyway ;-)
          file.reload
          file.register_helper if file.helper_file?
        end
      end
    end

    private

    def with_reloadable_files
      Dir[*paths].each do |file|
        yield FILES[file]
      end
    end

    def paths
      @paths ||=
        begin
          Harbor::registered_applications.map do |app|
            "#{app.root}/{controllers,models,helpers,forms}/**/*.rb"
          end
        end
    end

    class ReloadableFile
      attr_reader :path, :mtime

      def initialize(path)
        @path = ::File.expand_path(path)
        update
      end

      def remove_constant
        return unless controller_file?

        const_str = path.split('/').last.gsub('.rb', '').camelize
        constant = nil

        if @app.const_defined?(:Controllers)
          constant = @app::Controllers.const_get const_str if @app::Controllers.const_defined? const_str
        end

        unless constant
          constant = @app.const_get const_str if @app.const_defined? const_str
        end

        raise "Was not able to find controller constant for #{path}" unless constant

        puts "[DEBUG] undefining #{constant}" if ENV['DEBUG']
        names = constant.name.split('::')
        constant = names.pop

        mod = names.inject(Object) do |constant, name|
          constant.const_get(name, false)
        end

        mod.instance_eval { remove_const constant }
      end

      def controller_file?
        @controller_file ||=
          begin
            app && path =~ /^#{app.root}\/controllers\//
          end
      end

      def helper_file?
        @helper_file ||=
          begin
            app && path =~ /^#{app.root}\/helpers\//
          end
      end

      def register_helper
        return unless helper_file?

        helper = path.split('/').last.gsub('.rb', '').camelize
        config.helpers.register @app::Helpers.const_get helper
      end

      def update
        @mtime = ::File.mtime(path)
      end

      def updated?
        !removed? && mtime != ::File.mtime(path)
      end

      def removed?
        !::File.exist?(@path)
      end

      def required?
        $LOADED_FEATURES.include? path
      end

      def reload
        puts "[DEBUG] reloading #{path}" if ENV['DEBUG']
        $LOADED_FEATURES.delete path
        require path
      end

      def app
        @app ||= Harbor::registered_applications.find { |app| path =~ /^#{app.root}\// }
      end
    end
  end
end
