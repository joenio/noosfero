module ActsAsSearchable

  module ClassMethods
    def acts_as_searchable(options = {})
    end

    module InstanceMethods
    end

    module FindByContents

      def schema_name
      end

      def find_by_contents(query, ferret_options = {}, db_options = {})
      end
    end
  end
end

ActiveRecord::Base.send(:extend, ActsAsSearchable::ClassMethods)
