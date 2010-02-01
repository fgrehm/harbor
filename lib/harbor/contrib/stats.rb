module Harbor
  module Contrib
    class Stats

      require Pathname(__FILE__).dirname.expand_path + "stats/models/user_agent"
      require Pathname(__FILE__).dirname.expand_path + "stats/models/page_view"

      def self.orm=(orm)
        require Pathname(__FILE__).dirname.expand_path + "stats/orm/#{orm}"

        @orm = const_get(orm.gsub(/(^|_)(.)/) { $2.upcase })
      end

      def self.orm
        @orm
      end

    end
  end
end

Harbor::Application.register_event(:request_complete) do |request, |
  if orm = Harbor::Contrib::Stats.orm
    if request.session?
      session = request.session

      orm::PageView.create(session.id, request.uri, request.referrer)
      orm::UserAgent.create(session.id, request.remote_ip, request.env["HTTP_USER_AGENT"])
    end
  else    
    warn "Harbor::Contrib::Stats::orm must be set to generate statistics."
  end
end