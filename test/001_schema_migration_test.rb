###############################################################################
# DB Schema Migration for testing ActiveKirby
require 'active_record/migration'

class SchemaMigrationTest < ActiveRecord::Migration
  def self.up
    create_table "pages", :force => true do |t|
      t.column "book_id", :integer
      t.column "page_num", :integer
      t.column "content", :text
    end  

    remove_index(:delete_me_in_migration, :junk)
    rename_column(:delete_me_in_migration, :more_junk, :less_junk)
    change_column(:delete_me_in_migration, :junk, :string)
    remove_column(:delete_me_in_migration, :junk_yard)

    drop_table(:delete_me_in_migration)
    
    add_column(:publishers, :address, :string)
    add_index(:publishers, :name, :unique)

    # test belong_to (book) and has_one (book)
    create_table 'errata', :force => true do |t|
      t.column 'book_id', :integer
      t.column 'contents', :string
    end
  end

  def self.down
  end
end
