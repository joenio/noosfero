module Noosfero
  class MultiTenancy

    def self.mapping
      @mapping ||= self.load_map
    end

    def self.on?
      !self.mapping.blank? || self.is_hosted_environment?
    end

    def self.db_by_host=(host)
      ActiveRecord::Base.connection.schema_search_path = self.mapping[host]
    end

    private

    def self.load_map
      db_file = File.join(RAILS_ROOT, 'config', 'database.yml')
      db_config = YAML.load_file(db_file)
      map = { }
      db_config.each do |env, attr|
        next unless env.match(/_#{RAILS_ENV}$/) and attr['adapter'] =~ /^postgresql$/i
        attr['domains'].each { |d| map[d] = attr['schema_search_path'] }
      end
      map
    end

    def self.is_hosted_environment?
      db_file = File.join(RAILS_ROOT, 'config', 'database.yml')
      db_config = YAML.load_file(db_file)
      db_config.select{ |env, attr| RAILS_ENV.to_s.match(/_#{env}$/) }.any?
    end

  end
end
