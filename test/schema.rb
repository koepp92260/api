###############################################################################
# DB Schema for testing ActiveKirby

ActiveRecord::Schema.define() do

  create_table "books", :force => true do |t|
    t.column "name", :string, :null => false
    t.column "published", :date, :null => false
    t.column "publisher_id", :integer
  end

  add_index "books", ["name"], :name => "book_names_index"

  create_table "authors", :force => true do |t|
    t.column "name", :string, :null => false
  end

  add_index "authors", ["name"], :name => "author_names_index"

  create_table "authors_books", :force => true do |t|
    t.column "author_id", :integer
    t.column "book_id", :integer
  end

  create_table "publishers", :force => true do |t|
    t.column "name", :text
  end 
  
  create_table 'delete_me_in_migration', :force => true do |t|
    t.column "junk", :text, :dafault => 'food'
    t.column "more_junk", :integer
    t.column "junk_yard", :datetime
  end
  add_index "delete_me_in_migration", ["junk"], :name => "junk_index"

  create_table 'primary_key_tests', :force => true do |t|
    t.column 'pk', :primary_key
    t.column 'name', :string
  end
  
  create_table :nil_tests, :force => true do |t|
    t.column :nil_value, :integer
    t.column :conditional, :integer
  end

  create_table :date_and_time_tests, :force => true do |t|
    t.column :date_value, :date
    t.column :time_value, :time
  end
end
