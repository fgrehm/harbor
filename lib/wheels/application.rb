require "rack"
require "yaml"
require "thread"

require Pathname(__FILE__).dirname + "rack/utils"
require Pathname(__FILE__).dirname + "request"
require Pathname(__FILE__).dirname + "response"

class Application

  attr_reader :environment
  
  def initialize(router, environment = "development")
    @router = router
    @environment = environment.to_s
  end

  def not_found(request, response)
    response.flush
    response.status = 404
    response.puts "The page you requested could not be found"
    [response.status, response.headers, response.string.to_a]
  end

  def call(env)
    env["APP_ENVIRONMENT"] = environment
    request = Rack::Request.new(env)
    response = Response.new(request)
    handler = @router.match(request)
    return not_found(request, response) if handler == false

    handler.call(request, response)
    [response.status, response.headers, response.string.to_a]
  end

end
