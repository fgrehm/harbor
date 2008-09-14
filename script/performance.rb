require "rubygems"
require "rbench"
require "sinatra"
require Pathname(__FILE__).dirname.parent + "lib/framework"

module Rack
  class Request
    def params
      @params ||= {}
    end
  end
end

Sinatra.application.options.run = false

TIMES = 1_000

RBench.run(TIMES) do
  column :times
  column :wieck, :title => "Wieck"
  column :sinatra, :title => "Sinatra"
  column :diff, :compare => [:wieck, :sinatra]

  router = Router.new
  report "Create simple get route" do
    wieck { router.get("/") {} }
    sinatra { get("/") {} }
  end

  request = Rack::Request.new("PATH_INFO" => "/", "REQUEST_METHOD" => "GET")

  report "Match the last route" do
    Sinatra.application.events.clear
    router.clear

    # We define 100 routes, and then append "/" to the end
    100.times do |i|
      router.get("/#{i}") {}
      get("/#{i}") {}
    end
    router.get("/") {}
    get("/") {}

    wieck { router.match(request) }
    sinatra { Sinatra.application.lookup(request) }
  end

end