require 'kirbybase'

def create_and_init db
  db.create_table(:accounts,
    :firm_id, { :DataType => :Integer, :Default => nil },
    :credit_limit, { :DataType => :Integer, :Default => nil }
  )
  
  db.create_table(:companies,
    :type, { :DataType => :String, :Default => nil },
    :ruby_type, { :DataType => :String, :Default => nil },
    :firm_id, { :DataType => :Integer, :Default => nil },
    :name, { :DataType => :String, :Default => nil },
    :client_of, { :DataType => :Integer, :Default => nil },
    :rating, { :DataType => :Integer, :Default => 1 }
  )
  
  
  db.create_table(:topics,
    :title, { :DataType => :String, :Default => nil },
    :author_name, { :DataType => :String, :Default => nil },
    :author_email_address, { :DataType => :String, :Default => nil },
    :written_on, { :DataType => :Time, :Default => nil },
    :bonus_time, { :DataType => :Time, :Default => nil },
    :last_read, { :DataType => :Date, :Default => nil },
    :content, { :DataType => :String },
    :approved, { :DataType => :Boolean, :Default => true },
    :replies_count, { :DataType => :Integer, :Default => 0 },
    :parent_id, { :DataType => :Integer, :Default => nil },
    :type, { :DataType => :String, :Default => nil }
  )
  
  db.create_table(:developers,
    :name, { :DataType => :String, :Default => nil },
    :salary, { :DataType => :Integer, :Default => 70000 },
    :created_at, { :DataType => :Time, :Default => nil },
    :updated_at, { :DataType => :Time, :Default => nil }
  )
  
  db.create_table(:projects,
    :name, { :DataType => :String, :Default => nil },
    :type, { :DataType => :String, :Default => nil }
  )
  
  db.create_table(:developers_projects,
    :developer_id, { :DataType => :Integer, :Required => true },
    :project_id, { :DataType => :Integer, :Required => true },
    :joined_on, { :DataType => :Date, :Default => nil },
    :access_level, { :DataType => :Integer, :Default => 1 }
  )
  
  
  db.create_table(:orders,
    :name, { :DataType => :String, :Default => nil },
    :billing_customer_id, { :DataType => :Integer, :Default => nil },
    :shipping_customer_id, { :DataType => :Integer, :Default => nil }
  )
  
  db.create_table(:customers,
    :name, { :DataType => :String, :Default => nil },
    :balance, { :DataType => :Integer, :Default => 0 },
    :address_street, { :DataType => :String, :Default => nil },
    :address_city, { :DataType => :String, :Default => nil },
    :address_country, { :DataType => :String, :Default => nil },
    :gps_location, { :DataType => :String, :Default => nil }
  )
  
  db.create_table(:movies,
    :movieid, { :DataType => :Integer, :Required => true },
    :name, { :DataType => :String, :Default => nil }
  )
  
  db.create_table(:subscribers,
   :nick, { :DataType => :String, :Required => true },
   :name, { :DataType => :String, :Default => nil }
  )
  
  db.create_table(:booleantests,
    :value, { :DataType => :Boolean, :Default => nil }
  )
  
  db.create_table(:auto_id_tests,
    :auto_id, { :DataType => :Integer, :Calculated => "recno" }, # emulate the primary key in the adapter
    :value, { :DataType => :Integer, :Default => nil }
  )
  
  db.create_table(:entrants,
    :name, { :DataType => :String, :Required => true },
    :course_id, { :DataType => :Integer, :Required => true }
  )
  
  db.create_table(:colnametests,
    :references, { :DataType => :Integer, :Required => true }
  )
  
  db.create_table(:mixins,
    :parent_id, { :DataType => :Integer, :Default => nil },
    :type, { :DataType => :String, :Default => nil },
    :pos, { :DataType => :Integer, :Default => nil },
    :lft, { :DataType => :Integer, :Default => nil },
    :rgt, { :DataType => :Integer, :Default => nil },
    :root_id, { :DataType => :Integer, :Default => nil },
    :created_at, { :DataType => :Time, :Default => nil },
    :updated_at, { :DataType => :Time, :Default => nil }
  )
  
  db.create_table(:people,
    :first_name, { :DataType => :String, :Default => nil },
    :lock_version, { :DataType => :Integer, :Required => true, :Default => 0 }
  )
  
  db.create_table(:binaries,
    :data, { :DataType => :String }
  )
  
  db.create_table(:computers,
    :developer, { :DataType => :Integer, :Required => true },
    :extendedWarranty, { :DataType => :Integer, :Required => true }
  )
  
  db.create_table(:posts,
    :author_id, { :DataType => :Integer },
    :title, { :DataType => :String, :Required => true },
    :type, { :DataType => :String, :Required => true },
    :body, { :DataType => :String, :Required => true }
  )
  
  db.create_table(:comments,
    :post_id, { :DataType => :Integer, :Required => true },
    :type, { :DataType => :String, :Required => true },
    :body, { :DataType => :String, :Required => true }
  )
  
  db.create_table(:authors,
    :name, { :DataType => :String, :Required => true }
  )
  
  db.create_table(:tasks,
    :starting, { :DataType => :Time, :Default => nil },
    :ending, { :DataType => :Time, :Default => nil }
  )
  
  db.create_table(:categories,
    :name, { :DataType => :String, :Required => true },
    :type, { :DataType => :String, :Default => nil }
  )
  
  db.create_table(:categories_posts,
    :category_id, { :DataType => :Integer, :Required => true },
    :post_id, { :DataType => :Integer, :Required => true }
  )
  
  db.create_table(:fk_test_has_pk
  )
  
  db.create_table(:fk_test_has_fk,
    :fk_id, { :DataType => :Integer, :Required => true }
    # FOREIGN KEY ('fk_id') REFERENCES 'fk_test_has_pk'('id')
  )
  
  db.create_table(:keyboards,
    :key_number, { :DataType => :Integer, :Calculated => "recno" },
    :name, { :DataType => :String, :Default => nil }
  )
end

def create_and_init_2 db2
  db2.create_table(:courses,
   :name, { :DataType => :String, :Required => true }
  )
end
