require 'test_helper'

class KBSchemaTest < Test::Unit::TestCase

  def setup
    # recreate_kb_database(false)
    @adapter = ActiveRecord::Base.connection
  end

  def tear_down
  end

  def test_migrated_schema
    # load the schme.rb file and migration files
    recreate_kb_database(true)

    # check that all tables are in:
    assert_equal [:authors, :authors_books, :books, :date_and_time_tests, :errata, :nil_tests, :pages, :primary_key_tests, :publishers, :schema_info], 
                 $db.tables.sort_by{|t| t.to_s }
    assert_equal $db.tables.map{|t| t.to_s}, @adapter.tables

    # check books table
    assert_equal [:recno,   :name,     :published, :publisher_id], $db.get_table(:books).field_names        
    assert_equal [:Integer, :String,   :Date,      :Integer     ], $db.get_table(:books).field_types
    assert_equal [nil,      "Index->1", nil,       nil          ], $db.get_table(:books).field_indexes
    assert_equal [false,    true,       true,      false        ], $db.get_table(:books).field_requireds
    assert_equal [nil,      nil,        nil,       nil          ], $db.get_table(:books).field_defaults
    assert_equal [{},       {},         {},        {}           ], $db.get_table(:books).field_extras
    
    # check authors table
    assert_equal [:recno,   :name     ], $db.get_table(:authors).field_names
    assert_equal [:Integer, :String   ], $db.get_table(:authors).field_types
    assert_equal [nil,      "Index->1"], $db.get_table(:authors).field_indexes
    assert_equal [false,    true      ], $db.get_table(:authors).field_requireds
    assert_equal [nil,      nil       ], $db.get_table(:authors).field_defaults
    assert_equal [{},       {}        ], $db.get_table(:authors).field_extras

    # check authors_books table
    assert_equal [:recno,   :author_id, :book_id], $db.get_table(:authors_books).field_names
    assert_equal [:Integer, :Integer,   :Integer], $db.get_table(:authors_books).field_types
    assert_equal [nil,      nil,        nil     ], $db.get_table(:authors_books).field_indexes
    assert_equal [false,    false,      false   ], $db.get_table(:authors_books).field_requireds
    assert_equal [nil,      nil,        nil     ], $db.get_table(:authors_books).field_defaults
    assert_equal [{},       {},        {}       ], $db.get_table(:authors_books).field_extras

    # check pages table
    assert_equal [:recno,   :book_id, :page_num, :content], $db.get_table(:pages).field_names
    assert_equal [:Integer, :Integer, :Integer,  :String ], $db.get_table(:pages).field_types
    assert_equal [nil,      nil,      nil,       nil     ], $db.get_table(:pages).field_indexes
    assert_equal [false,    false,    false,     false   ], $db.get_table(:pages).field_requireds
    assert_equal [nil,      nil,      nil,       nil     ], $db.get_table(:pages).field_defaults
    assert_equal [{},       {},       {},        {}       ], $db.get_table(:pages).field_extras

    # check publishers table
    assert_equal [:recno,   :name,      :address], $db.get_table(:publishers).field_names
    assert_equal [:Integer, :String,    :String ], $db.get_table(:publishers).field_types
    assert_equal [nil,      "Index->1", nil     ], $db.get_table(:publishers).field_indexes
    assert_equal [false,    false,      false   ], $db.get_table(:publishers).field_requireds
    assert_equal [nil,      nil,        nil     ], $db.get_table(:publishers).field_defaults
    assert_equal [{},       {},         {}      ], $db.get_table(:publishers).field_extras

    # check errata table
    assert_equal [:recno,   :book_id,   :contents], $db.get_table(:errata).field_names
    assert_equal [:Integer, :Integer,   :String  ], $db.get_table(:errata).field_types
    assert_equal [nil,      nil,        nil      ], $db.get_table(:errata).field_indexes
    assert_equal [false,    false,      false    ], $db.get_table(:errata).field_requireds
    assert_equal [nil,      nil,        nil      ], $db.get_table(:errata).field_defaults
    assert_equal [{},       {},         {}       ], $db.get_table(:errata).field_extras
  end

  def x_test_create_table
    flunk
  end
  
  def x_test_rename_table
    flunk
  end

  def x_test_indexes
    breakpoint
    i = ActiveRecord::ConnectionAdapters::IndexDefinition.new(:authors, '1', true, [:name])
    assert_equal [i], Author.indexes
    i = ActiveRecord::ConnectionAdapters::IndexDefinition.new(:books, '1', true, [:name])
    assert_equal [i], Book.indexes
    assert_equal [], Page.indexes
    i = ActiveRecord::ConnectionAdapters::IndexDefinition.new(:publishers, '1', true, [:name])
    assert_equal [], Publisher.indexes
  end

  def x_test_drop_table
    flunk
  end

  def x_test_add_column
    flunk
  end

  def x_test_change_column
    flunk
  end

  def x_test_change_column_default
    flunk
  end
  
  def x_test_rename_column
    flunk
  end

  def x_test_remove_column
    flunk
  end

  def x_test_add_index
    flunk
  end

  def x_test_remove_index
    flunk
  end

  def x_test_tables
    flunk
  end
  
  def test_columns
    columns = Book.columns
    
    assert_equal 4, columns.size
    assert_equal ["id",      "name",    "published", "publisher_id"], columns.map {|col| col.name }
    assert_equal [:integer,  :string,   :date,       :integer      ], columns.map {|col| col.type }
    assert_equal [true,      false,      false,      true          ], columns.map {|col| col.null }
    assert_equal [nil,       nil,        nil,        nil           ], columns.map {|col| col.default }

    assert !columns[0].text?
    assert columns[1].text?
    assert !columns[2].text?
    assert !columns[3].text?
    
    assert columns.all? { |col| col.default.nil? }
    
    assert columns[0].number?
    assert !columns[1].number?
    assert !columns[2].number?
    assert columns[3].number?
  end
  
  def test_indexes
    @adapter.create_table "index_tests", :force => true do |t|
      t.column "indy_1", :integer
      t.column "indy_2", :string
      t.column "indy_3", :text
    end
    assert_nothing_raised { @adapter.add_index "index_tests", ["indy_1"], :name => "names_are_of_no_consequence" }
    assert_nothing_raised { @adapter.add_index "index_tests", ["indy_2", "indy_3"], :name => "names_are_of_no_consequence_2" }
    indices = @adapter.indexes("index_tests")
    assert_equal 2, indices.size
    assert_equal [["indy_1"], ["indy_2", "indy_3"]], indices.map{|ind| ind.columns}.sort
    assert_equal ["index_tests_indy_1_index", "index_tests_indy_2_index"], indices.map{|ind| ind.name}.sort
  end
  
  def test_primary_key
    pak = PrimaryKeyTest.create :name => 'first'
    assert_equal 1, pak.id
    assert_equal 1, pak.pk
    
  end

end
