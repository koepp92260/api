module ActiveRecord
  module Associations
    module ClassMethods
      def remove_association *names
        if names.length == 1
          assocs = @inheritable_attributes[:associations].select{ |a| a.name == names[0] }
          assocs.each {|assoc| @inheritable_attributes[:associations].delete assoc }
        else
          names.each {|assoc| remove_association(assoc)}
        end
      end
      def has_and_belongs_to_many_without_method_redefinition(association_id, options = {}, &extension)
        options.assert_valid_keys(
          :class_name, :table_name, :foreign_key, :association_foreign_key, :conditions, :include,
          :join_table, :finder_sql, :delete_sql, :insert_sql, :order, :uniq, :before_add, :after_add, 
          :before_remove, :after_remove, :extend
        )

        options[:extend] = create_extension_module(association_id, extension) if block_given?

        association_name, association_class_name, association_class_primary_key_name =
              associate_identification(association_id, options[:class_name], options[:foreign_key])

        require_association_class(association_class_name)

        options[:join_table] ||= join_table_name(undecorated_table_name(self.to_s), undecorated_table_name(association_class_name))

        add_multiple_associated_save_callbacks(association_name)
      
        collection_accessor_methods(association_name, association_class_name, association_class_primary_key_name, options, HasAndBelongsToManyAssociation)

        add_association_callbacks(association_name, options)
        
        # deprecated api
        deprecated_collection_count_method(association_name)
        deprecated_add_association_relation(association_name)
        deprecated_remove_association_relation(association_name)
        deprecated_has_collection_method(association_name)
      end
    end
  end
end

class Company < ActiveRecord::Base
  set_sequence_name nil
end

class Firm
  remove_association :clients, :clients_of_firm, :clients_using_sql, :clients_using_counter_sql,
                     :clients_using_zero_counter_sql, :no_clients_using_counter_sql
  
  has_many :clients, :order => "id", :dependent => true, :counter_sql =>
           lambda {|rec, firm| rec.firm_id == 1 and ['Client', 'SpecialClient', 'VerySpecialClient'].include?(rec.type) }
           # "SELECT COUNT(*) FROM companies WHERE firm_id = 1 " +
           # "AND (#{QUOTED_TYPE} = 'Client' OR #{QUOTED_TYPE} = 'SpecialClient' OR #{QUOTED_TYPE} = 'VerySpecialClient' )"

  has_many :clients_of_firm, :foreign_key => "client_of", :class_name => "Client", :order => "id"
  has_many :clients_using_sql, :class_name => "Client",
           :finder_sql => lambda{|rec, firm| rec.client_of == firm.id} # 'SELECT * FROM companies WHERE client_of = #{id}'
  has_many :clients_using_counter_sql, :class_name => "Client",
           :finder_sql  => lambda{|rec, firm| rec.client_of == firm.id}, # 'SELECT * FROM companies WHERE client_of = #{id}',
           :counter_sql => lambda{|rec, firm| rec.client_of == firm.id}  # 'SELECT COUNT(*) FROM companies WHERE client_of = #{id}'
  has_many :clients_using_zero_counter_sql, :class_name => "Client",
           :finder_sql  => lambda{|rec, firm| rec.client_of == id}, # 'SELECT * FROM companies WHERE client_of = #{id}'
           :counter_sql => lambda{|rec, firm| false } # 'SELECT 0 FROM companies WHERE client_of = #{id}'
  has_many :no_clients_using_counter_sql, :class_name => "Client",
           :finder_sql  => lambda{|rec, firm| rec.client_of == 1000}, # 'SELECT * FROM companies WHERE client_of = 1000'
           :counter_sql => lambda{|rec, firm| rec.client_of == 1000}  # 'SELECT COUNT(*) FROM companies WHERE client_of = 1000'
end

class Client < Company
  belongs_to :firm_with_condition, :class_name => "Firm", :foreign_key => "client_of", :conditions => "1 = 1"
end

# module MyApplication
#   module Business
#     class Firm
#       has_many :clients_using_sql, :class_name => "Client", 
#                :finder_sql => lambda{|rec, firm| rec.client_of == firm.id} # 'SELECT * FROM companies WHERE client_of = #{id}'
#     end
#   end
# end 

class Project
  remove_association :developers_with_finder_sql, :developers_by_sql

  ## Unfortunately calling habtm with the same name again will cause some method
  # redefinition loop (see associations.rb for the dynamic method redefinition).
  # So we have to go through loops to redefine the exact methods.
  has_and_belongs_to_many_without_method_redefinition :developers_with_finder_sql, :class_name => "Developer",
                          # :finder_sql => 'SELECT t.*, j.* FROM developers_projects j, developers t WHERE t.id = j.developer_id AND j.project_id = #{id}'
                          :finder_sql => lambda{|join, project| join.project_id == project.id } # this is run on the join table
                          
  has_and_belongs_to_many_without_method_redefinition :developers_by_sql, :class_name => "Developer",
                          # :delete_sql => "DELETE FROM developers_projects WHERE project_id = \#{id} AND developer_id = \#{record.id}"
                          :delete_sql => lambda{|join, project, developer| join.project_id == project.id and join.developer_id == developer.id}
end

