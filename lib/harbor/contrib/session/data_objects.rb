require "base64"
require "data_objects"

module Harbor
  module Contrib
    class Session
      ##
      # This is a database backed session handle for DataObjects. You can use it
      # instead of the builtin Harbor::Session::Cookie by doing:
      # 
      #   Harbor::Session.configure do |session|
      #     session[:store] = Harbor::Contrib::Session::DataObjects
      #     session[:connection] = DataObjects::Connection.new('sqlite3://session.db')
      #   end
      ##
      class DataObjects < Harbor::Session::Abstract

        class SessionHash < Hash
          def initialize(instance)
            super()
            @instance = instance
            merge!(@instance[:data])
          end
          
          def [](key)
            key == :session_id ? @instance[:session_id] : super
          end

          def []=(key, value)
            raise ArgumentError.new("You cannot manually set the session_id for a session.") if key == :session_id

            super
          end

          def to_hash
            {}.merge(reject { |key,| key == :session_id })
          end
        end

        def self.load_session(cookie)
          create_session_table unless session_table_exists?
        
          session = if expire_after = Harbor::Session.options[:expire_after]
            get_raw_session(cookie, Time.now - expire_after)
          else
            get_raw_session(cookie)
          end
          
          session ||= create_session

          SessionHash.new(session)
        end

        def self.commit_session(data, request)
          cmd = connection.create_command("UPDATE sessions SET data = ?, updated_at = ?;")
          
          cmd.execute_non_query(self.dump(data.to_hash), Time.now)
          
          data[:session_id]
        end
        
        def self.session_table_exists?        
          return @table_exists unless @table_exists.nil?
        
          table_exists_sql = "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'sessions';"
          cmd = connection.create_command(table_exists_sql)
          reader = cmd.execute_reader
          
          @table_exists = (reader.next! != false)
          
          reader.close
          
          @table_exists
        end
        
        def self.create_session_table
          return if (@table_exists == true)
        
          create_table_sql = "CREATE TABLE IF NOT EXISTS sessions (id VARCHAR(50) NOT NULL, data TEXT, created_at DATETIME, updated_at DATETIME, PRIMARY KEY(id))"
          cmd = connection.create_command(create_table_sql)
          cmd.execute_non_query
          
          @table_exists = true
        end
        
        def self.create_session(data = {})
          session_id = `uuidgen`.chomp

          cmd = connection.create_command("INSERT INTO sessions (id, data, created_at, updated_at) VALUES (?, ?, ?, ?);")
          
          cmd.execute_non_query(session_id, self.dump(data), Time.now, Time.now)
          
          {:session_id => session_id, :data => data}
        end
        
        def self.get_raw_session(cookie, updated_at=nil)
          query = "SELECT id, data FROM sessions WHERE id = ? "
          params = [cookie]
          
          if updated_at
            query << ' AND updated_at >= ?'
            params << updated_at
          end
          query << ' LIMIT 1'
        
          cmd = connection.create_command(query)
          reader = cmd.execute_reader(*params)
          
          if ! reader.next!
            reader.close
            return nil
          end          
          
          raw = {}
          raw[:session_id] = reader.values[0]          
          raw[:data] = self.load(reader.values[1])
          
          reader.close
          
          raw
        end
        
      protected 
        
        def self.connection
          Harbor::Session.options[:connection]
        end
        
        def self.dump(data)
          Base64.encode64(Marshal.dump(data))
        end
        
        def self.load(data)
          Marshal.load(Base64.decode64(data))
        end
      end
    end
  end
end