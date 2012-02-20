require "set"
require "harbor/controller/router/route"

module Harbor
  class Controller
    class Router
      
      PATH_SEPARATOR = /[\/:;]/
      
      def initialize
        @methods = {
          "GET"     => [],
          "POST"    => [],
          "PUT"     => [],
          "DELETE"  => [],
          "OPTIONS" => []
        }
      end
      
      def register(method, path, controller, action_name)
        @methods[method] << Route.new(path, controller, action_name)
      end
      
      def match(method, path)
        @methods[method].index(path)
      end

      def self.instance
        @instance ||= self.new
      end
    end
  end
end