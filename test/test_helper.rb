
require 'test/unit'

require_gem 'rails'
require 'active_record'
require 'active_record/migration'
require 'active_record/fixtures'
require 'active_support/breakpoint'
require 'kirbybase_adapter'
require 'model'

ActiveRecord::Base.logger = Logger.new("test.log")

###############################################################################
# Database Utilities
$TEST_DB_LOCATION = File.join(File.dirname(__FILE__), 'db')

def recreate_kb_database(load_schema = true)
  FileUtils.rm_rf $TEST_DB_LOCATION rescue nil
  FileUtils.mkdir_p $TEST_DB_LOCATION
  
  ActiveRecord::Base.establish_connection(
    :adapter  => "kirbybase",
    :connection_type => "local",
    :dbpath => $TEST_DB_LOCATION
  )
  ActiveRecord::Base.clear_connection_cache!
  $db = ActiveRecord::Base.connection.db # use the same KirbyBase object that the ActiveRecord adapter uses

  if load_schema
    load File.join(File.dirname(__FILE__), 'schema.rb')
    ActiveRecord::Migrator.migrate(File.expand_path(File.dirname(__FILE__)) + "/", 1)
  end
end

###############################################################################
# Start tests: This will do 3 things:
# Create the DB path, establish connection and load the test schema
# Load the schema
# The schema.rb file contains basic schema instructions, and is the functional
# testing of basic AR::Schema compatibility. # Migrate the schema
# This test will load the migration files. These files both test the integration
# and support of ActiveRecord::Migrations, and more advanced schema operations
#
# All AR::Schema functionality to test goes in the schema.rb file or in the migration
# file, as appropriate.
# 
puts "Recreating Database..."
recreate_kb_database