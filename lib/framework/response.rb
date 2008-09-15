require "stringio"

class Response < StringIO

  attr_accessor :status, :content_type, :headers

  def initialize
    @headers = {}
    @content_type = "text/html"
    @status = 200
    super("")
  end

  def headers
    @headers.merge({
      "Content-Type" => self.content_type,
      "Content-Length" => self.size.to_s
    })
  end

  def puts(content)
    self.content_type = content.content_type if content.respond_to?(:content_type)
    super(content.to_s)
  end

end