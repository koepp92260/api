require 'test_helper'

@@AR_PATH = Gem.latest_load_paths.grep(/activerecord/)[0]
@@AR_TESTS_PATH = File.expand_path(File.join(@@AR_PATH, '../test'))
$LOAD_PATH << @@AR_TESTS_PATH

################################################################################
### Start requiring ActiveRecords test files ###################################
# There are 663 tests, 2188 assertions in the AR test suite (sqlite)

################################################################################
# ActiveRecord::Base basics tests
require File.join(@@AR_TESTS_PATH, 'base_test.rb')
class BasicsTest
  # too much SQL
  remove_method :test_count_with_join
end

################################################################################
# ActiveRecord::Associations tests
require File.join(@@AR_TESTS_PATH, 'associations_test.rb')

class AssociationsTest
  # We use code blocks (procs) which can't be dumped with Marshal
  remove_method :test_storing_in_pstore
end

class HasAndBelongsToManyAssociationsTest
  # Joins not supported
  remove_method :test_adding_uses_default_values_on_join_table
  remove_method :test_adding_uses_explicit_values_on_join_table
  remove_method :test_additional_columns_from_join_table
end

class HasManyAssociationsTest
  # :group option (GROUP BY statement) not supported
  remove_method :test_find_grouped
  # transactions not supported
  remove_method :test_dependence_with_transaction_support_on_failure
end

class HasAndBelongsToManyAssociationsTest
  # just changes the last select count to work through KB select blocks
  def test_update_attributes_after_push_without_duplicate_join_table_rows
    developer = Developer.new("name" => "Kano")
    project = SpecialProject.create("name" => "Special Project")
    assert developer.save
    developer.projects << project
    developer.update_attribute("name", "Bruza")
    # assert_equal 1, Developer.connection.select_value(<<-end_sql).to_i
    #   SELECT count(*) FROM developers_projects
    #   WHERE project_id = #{project.id}
    #   AND developer_id = #{developer.id}
    # end_sql
    num_rows = Developer.connection.db.get_table(:developers_projects).select do |rec|
      rec.project_id == project.id and rec.developer_id == developer.id
    end.size
    assert_equal 1, num_rows
  end

  def test_removing_associations_on_destroy
    david = DeveloperWithBeforeDestroyRaise.find(1)
    assert !david.projects.empty?
    assert_nothing_raised { david.destroy }
    assert david.projects.empty?
    assert DeveloperWithBeforeDestroyRaise.connection.db.get_table(:developers_projects).select{|rec| rec.developer_id == 1}.empty?
  end

end

require File.join(@@AR_TESTS_PATH, 'associations_extensions_test.rb')

class AssociationsExtensionsTest
  # Procs can't be marshalled
  remove_method :test_marshalling_extensions
  remove_method :test_marshalling_named_extensions
end

require File.join(@@AR_TESTS_PATH, 'deprecated_associations_test.rb')

class DeprecatedAssociationsTest
  remove_method :test_has_many_dependence_with_transaction_support_on_failure
  remove_method :test_storing_in_pstore
end

################################################################################
# Finder tests
require File.join(@@AR_TESTS_PATH, 'finder_test.rb')

class FinderTest
  # we don't allow full SQL, but might as well check the block format
  def test_count_by_sql
    assert_raises(ActiveRecord::StatementInvalid) { Entrant.count_by_sql("SELECT COUNT(*) FROM entrant") }
    assert_equal 0, Entrant.count(lambda{|rec| rec.recno > 3})
    # this is just too wierd: assert_equal 1, Entrant.count([lambda{|rec| rec.recno > 2}])
    assert_equal 2, Entrant.count{|rec| rec.recno > 1}
  end
  remove_method :test_find_with_entire_select_statement
  remove_method :test_find_with_prepared_select_statement
  remove_method :test_select_value
  remove_method :test_select_values
  remove_method :test_find_all_with_join
end

require File.join(@@AR_TESTS_PATH, 'deprecated_finder_test.rb')

class DeprecatedFinderTest
  remove_method :test_count_by_sql
end

################################################################################
# Schema & Migrations tests

require File.join(@@AR_TESTS_PATH, 'ar_schema_test.rb')

class ActiveRecordSchemaTest
  def test_schema_define
    ActiveRecord::Schema.define(:version => 7) do
      create_table :fruits do |t|
        t.column :color, :string
        t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
        t.column :texture, :string
        t.column :flavor, :string
      end
    end

    assert_nothing_raised { @connection.get_table(:fruits).select }
    assert_nothing_raised { @connection.get_table(:schema_info).select }
    assert_equal 7, @connection.get_table(:schema_info).select[0].version
  end
end

require File.join(@@AR_TESTS_PATH, 'migration_test.rb')

class MigrationTest
  def teardown
    ActiveRecord::Base.connection.initialize_schema_information
    ActiveRecord::Base.connection.get_table(:schema_info).update_all {|rec| rec.version = 0}

    Reminder.connection.drop_table("reminders") rescue nil
    Reminder.connection.drop_table("people_reminders") rescue nil
    Reminder.connection.drop_table("prefix_reminders_suffix") rescue nil
    Reminder.reset_column_information

    Person.connection.remove_column("people", "last_name") rescue nil
    Person.connection.remove_column("people", "bio") rescue nil
    Person.connection.remove_column("people", "age") rescue nil
    Person.connection.remove_column("people", "height") rescue nil
    Person.connection.remove_column("people", "birthday") rescue nil
    Person.connection.remove_column("people", "favorite_day") rescue nil
    Person.connection.remove_column("people", "male") rescue nil
    Person.connection.remove_column("people", "administrator") rescue nil
    Person.reset_column_information
  end

  def test_create_table_with_not_null_column
    Person.connection.create_table :testings do |t|
      t.column :foo, :string, :null => false
    end

    # ArgumentError and not ActiveRecord::StatementInvalid because we're inserting directly to the db.
    # Still showns that this field is required
    assert_raises(ArgumentError) do
      Person.connection.get_table(:testings).insert :foo => nil
    end
  ensure
    Person.connection.drop_table :testings rescue nil
  end

  def test_add_column_not_null_with_default
    Person.connection.create_table :testings do |t|
      t.column :foo, :string
    end
    Person.connection.add_column :testings, :bar, :string, :null => false, :default => "default"

    # changed from ActiveRecord::StatementInvalid as we're operating directly on
    # the database, and that is what KB spits out. Still, it validates that the
    # field is now required (not null)
    assert_raises(ArgumentError) do
      Person.connection.get_table(:testings).insert :foo => 'hello', :bar => nil
    end
  ensure
    Person.connection.drop_table :testings rescue nil
  end

  def test_add_column_not_null_without_default
    Person.connection.create_table :testings do |t|
      t.column :foo, :string
    end
    Person.connection.add_column :testings, :bar, :string, :null => false

    assert_raises(ArgumentError) do
      Person.connection.get_table(:testings).insert :foo => 'hello', :bar => nil
    end
  ensure
    Person.connection.drop_table :testings rescue nil
  end

  # KirbyBase only supports one index per column, so created new column
  # (middle_name) for those tests. Also, KirbyBase does not support named
  # indexes, so those tests were disabled.
  def test_add_index
    Person.connection.add_column "people", "last_name", :string        
    Person.connection.add_column "people", "middle_name", :string        
    Person.connection.add_column "people", "administrator", :boolean

    assert_nothing_raised { Person.connection.add_index("people", "last_name") }
    assert_nothing_raised { Person.connection.remove_index("people", "last_name") }

    assert_nothing_raised { Person.connection.add_index("people", ["middle_name", "first_name"]) }
    assert_nothing_raised { Person.connection.remove_index("people", "last_name") }

    # assert_nothing_raised { Person.connection.add_index("people", %w(last_name middle_name administrator), :name => "named_admin") }
    # assert_nothing_raised { Person.connection.remove_index("people", :name => "named_admin") }
  end

  def test_rename_table
    begin
      ActiveRecord::Base.connection.create_table :octopuses do |t|
        t.column :url, :string
      end
      ActiveRecord::Base.connection.rename_table :octopuses, :octopi

      assert_nothing_raised do
        ActiveRecord::Base.connection.get_table(:octopi).insert :url => 'http://www.foreverflying.com/octopus-black7.jpg'
      end

      assert_equal 'http://www.foreverflying.com/octopus-black7.jpg', 
                   ActiveRecord::Base.connection.get_table(:octopi).select{|r|r.recno == 1}.first.url

    ensure
      ActiveRecord::Base.connection.drop_table :octopuses rescue nil
      ActiveRecord::Base.connection.drop_table :octopi rescue nil
    end
  end

  # Since this test uses  aboolean field with a default, we need to override the
  # change_column statement to use FalseClass rather than 0.
  # In real life migrations, this should be guarded with an if current_adapter ...
  def test_change_column_with_new_default
    Person.connection.add_column "people", "administrator", :boolean, :default => true
    Person.reset_column_information            
    assert Person.new.administrator?
    
    assert_nothing_raised { Person.connection.change_column "people", "administrator", :boolean, :default => false }
    Person.reset_column_information            
    assert !Person.new.administrator?
  end    
end

################################################################################
# Misc tests

require File.join(@@AR_TESTS_PATH, 'inheritance_test.rb')

class InheritanceTest
  # not supporting non-integer primary keys just yet
  remove_method :test_inheritance_without_mapping

  def test_a_bad_type_column
    recno = Company.table.insert :mame => 'bad_class!', :type => 'Not happening'
    assert_raises(ActiveRecord::SubclassNotFound) { Company.find(recno) }
  end
end

require File.join(@@AR_TESTS_PATH, 'method_scoping_test.rb')

class MethodScopingTest
  # changed the LIKE clause to ruby block
  def test_scoped_count
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      assert_equal 1, Developer.count
    end

    Developer.with_scope(:find => { :conditions => 'salary = 100000' }) do
      assert_equal 8, Developer.count
      # assert_equal 1, Developer.count("name LIKE 'fixture_1%'")
      assert_equal 1, Developer.count(lambda{|rec| rec.name =~ /fixture_1.*/})
    end
  end
end

class HasAndBelongsToManyScopingTest
  # we don't use the nested scopes
  remove_method :test_raise_on_nested_scope
end

require File.join(@@AR_TESTS_PATH, 'pk_test.rb')

# Strings not supported for primary keys
class PrimaryKeysTest
  remove_method :test_string_key
  remove_method :test_find_with_more_than_one_string_key
end

require File.join(@@AR_TESTS_PATH, 'reflection_test.rb')

# We don't keep limits on Strings (and others). Using plain Ruby types.
class ReflectionTest
  remove_method :test_column_string_type_and_limit
end


################################################################################
# Require all other test files not specifically handled above

ar_test_files = Dir[@@AR_TESTS_PATH + '/*_test.rb']
# Remove things we don't support
%w{
  aaa_create_tables_test.rb
  transactions_test.rb
  associations_go_eager_test.rb
  mixin_test.rb
  mixin_nested_set_test.rb
}.each {|test_file| ar_test_files.delete File.join(@@AR_TESTS_PATH, test_file)}
ar_test_files.each {|test_file| require test_file}

class BinaryTest
  def setup
    Binary.table.clear
    @data = File.read(BINARY_FIXTURE_PATH).freeze
  end
end

class FixturesTest
  def test_inserts
    topics = create_fixtures("topics")
    # firstRow = ActiveRecord::Base.connection.select_one("SELECT * FROM topics WHERE author_name = 'David'")
    firstRow = ActiveRecord::Base.connection.db.get_table(:topics).select{|rec| rec.author_name == 'David'}.first
    assert_equal("The First Topic", firstRow["title"])

    # secondRow = ActiveRecord::Base.connection.select_one("SELECT * FROM topics WHERE author_name = 'Mary'")
    secondRow = ActiveRecord::Base.connection.db.get_table(:topics).select{|rec| rec.author_name == 'Mary'}.first
    assert_nil(secondRow["author_email_address"])
  end

  def test_inserts_with_pre_and_suffix
    ActiveRecord::Base.connection.create_table :prefix_topics_suffix do |t|
      t.column :title, :string
      t.column :author_name, :string
      t.column :author_email_address, :string
      t.column :written_on, :datetime
      t.column :bonus_time, :time
      t.column :last_read, :date
      t.column :content, :text
      t.column :approved, :boolean, :default => 1
      t.column :replies_count, :integer, :default => 0
      t.column :parent_id, :integer
      t.column :type, :string, :limit => 50
    end

    # Store existing prefix/suffix
    old_prefix = ActiveRecord::Base.table_name_prefix
    old_suffix = ActiveRecord::Base.table_name_suffix

    # Set a prefix/suffix we can test against
    ActiveRecord::Base.table_name_prefix = 'prefix_'
    ActiveRecord::Base.table_name_suffix = '_suffix'

    topics = create_fixtures("topics")

    # Restore prefix/suffix to its previous values
    ActiveRecord::Base.table_name_prefix = old_prefix 
    ActiveRecord::Base.table_name_suffix = old_suffix 

    # firstRow = ActiveRecord::Base.connection.select_one("SELECT * FROM prefix_topics_suffix WHERE author_name = 'David'")
    firstRow = ActiveRecord::Base.connection.db.get_table(:prefix_topics_suffix).select{|rec| rec.author_name == 'David'}.first
    assert_equal("The First Topic", firstRow["title"])

    # secondRow = ActiveRecord::Base.connection.select_one("SELECT * FROM prefix_topics_suffix WHERE author_name = 'Mary'")
    secondRow = ActiveRecord::Base.connection.db.get_table(:prefix_topics_suffix).select{|rec| rec.author_name == 'Mary'}.first
    assert_nil(secondRow["author_email_address"])        
  ensure
    ActiveRecord::Base.connection.drop_table :prefix_topics_suffix rescue nil
  end
end

# Too SQL specific
class TestColumnAlias
  # can't remove_method, because it's the only one in the textcase
  def test_column_alias() end
end

################################################################################
# Introduce my adaptation of the model classes (override SQL with blocks)
require 'ar_model_adaptation'

# schema_test and schema_dumper_test require from relative URLs, which means they
# override my changes. So the changes are reintroduced here.
module ActiveRecord #:nodoc:
  class Schema
    def self.define(info={}, &block)
      instance_eval(&block)

      unless info.empty?
        initialize_schema_information
        ActiveRecord::Base.connection.get_table(ActiveRecord::Migrator.schema_info_table_name.to_sym).update_all(info)
      end
    end
  end
  
  class SchemaDumper
    def initialize(connection)
      @connection = connection
      @types = @connection.native_database_types
      @info = @connection.get_table(:schema_info).select[0] rescue nil
    end
  end
end

# This is required as KirbyBase does not support transactions.
ObjectSpace.each_object(Class) do |test|
   test.use_transactional_fixtures = false if test < Test::Unit::TestCase
end

