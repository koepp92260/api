
require 'test_helper'

class KBBasicsTest < Test::Unit::TestCase
  
  self.fixture_path = File.expand_path(File.dirname(__FILE__)) + '/fixtures'
  use_transactional_fixtures = false 	 
  fixtures :publishers, :authors, :books, :pages, :authors_books

  def setup
    # recreate_kb_database
    # load_kb_fixtures
  end

  def tear_down
    # unload_kb_fixtures
  end

  def test_add_records
    # Start with a clean slate - Fixture insert directly to DB; here we test
    # insertion through AR::Base.create
    recreate_kb_database

    # Plain Inserts:
    authors = $db.get_table :authors
    assert [], authors.select
    
    Author.create :name => 'Andy Hunt'
    Author.create :name => 'Dave Thomas'
    assert_equal ['Andy Hunt', 'Dave Thomas'], authors.select.map { |a| a.name }.sort
    
    publishers = $db.get_table :publishers
    assert [], publishers.select
    pragprog = Publisher.create :name => "Pragmatic Programmers' Bookshelf"
    assert_equal ["Pragmatic Programmers' Bookshelf"], publishers.select.map { |a| a.name }

    # Inserts with a belongs_to association:
    books = $db.get_table :books
    assert_equal [], books.select
    pickaxe = Book.create :name => 'Programming Ruby (1st Edition)', :published => Date.parse('2000-01-01'), 
                :publisher => pragprog
    assert_equal [['Programming Ruby (1st Edition)', Date.parse('2000-01-01'), pragprog.id]],
                 books.select.map {|b| [b.name, b.published, b.publisher_id] }
    
    # Inserts with a belongs_to association:
    pages = $db.get_table :pages
    assert_equal 0, pages.select.size
    Page.create :book => pickaxe, :page_num => 0, :content => 'front cover'
    Page.create :book => pickaxe, :page_num => 1, :content => 'chapter 1'*256
    Page.create :book => pickaxe, :page_num => 2, :content => 'chapter 2'*512
    Page.create :book => pickaxe, :page_num => 3, :content => 'chapter 3'*513
    Page.create :book => pickaxe, :page_num => 4, :content => 'back cover'
    assert_equal 5, pages.select.size
    assert pages.select.all? { |page| page.book_id == pickaxe.id }
  end

  def test_find
    # test plain find :all
    assert_equal [@andy, @dave], Author.find(:all)

    # test plain find :first
    assert_equal @andy, Author.find(:first)

    # test find with block on :conditions parameter:
    assert_equal [@andy].map{|a| a.name}, Author.find(:all, :conditions => lambda{ |rec| rec.name =~ /andy/i }).map{|a| a.name}

    # test find with block:
    assert_equal [@dave].map{|a| a.name}, Author.find(:all) { |rec| rec.name =~ /Thomas/ }.map{|a| a.name}

    # test find_by_<property> methods:
    assert_equal @dave.name, Author.find_by_name('Dave Thomas').name
  end

  def test_find_by_ids
    # find by IDs
    assert_equal @andy, Author.find(1)
    assert_equal [@andy, @dave], Author.find(1,2)
    assert_equal [@andy, @dave], Author.find([1,2])
    pickaxe_id = $db.get_table(:books).select[0].recno
    assert_equal @pickaxe, Book.find_by_id(pickaxe_id)

    assert_equal @andy, Author.find('1')
    assert_equal [@andy, @dave], Author.find('1','2')
  end

  def test_find_with_sql_fragments
    # basic SQL strings should work:
    assert_equal [@andy], Author.find(:all, :conditions => "name = 'Andy Hunt'")

    # guess find with basic SQL fragment:
    assert_nothing_raised() { Author.find(:all, :conditions => ['name =?', 'Andy Hunt']) }
    assert_equal [@andy], Author.find(:all, :conditions => ['name =?', 'Andy Hunt'])
    assert_equal @dave, Author.find(:first, :conditions => ['name =?', 'Dave Thomas'])

    # test more complex SQL fragments:
    assert_equal [@back], Page.find(:all, :conditions => ["book_id = ? AND content = ?", 1, 'back cover'])
  end
  
  def test_update
    tbl = $db.get_table(:books)
    assert_equal 'Programming Ruby (1st Edition)', tbl.select.first.name
    
    pickaxe = Book.find :first
    pickaxe.name = 'Programming Ruby (2nd Edition)'
    pickaxe.publisher_id = 1
    pickaxe.save

    assert_equal 1, tbl.select.size
    assert_equal 'Programming Ruby (2nd Edition)', tbl.select.first.name
  end
 
  def test_update_all
    tbl = $db.get_table(:authors)
    assert_equal ['Andy Hunt', 'Dave Thomas'], tbl.select.map{|r| r.name}
    
    Author.update_all lambda{|rec| rec.name = rec.name.upcase}
    assert_equal ['ANDY HUNT', 'DAVE THOMAS'], tbl.select.map{|r| r.name}
    
    Author.update_all lambda{|rec| rec.name = rec.name.downcase}, lambda{|rec| rec.name =~ /Andy/i}
    assert_equal ['andy hunt', 'DAVE THOMAS'], tbl.select.map{|r| r.name}

    Author.update_all "name = 'Andy'", lambda{|rec| rec.name =~ /Andy/i}
    assert_equal ['Andy', 'DAVE THOMAS'], tbl.select.map{|r| r.name}

    Author.update_all ['name = ?', 'Mr. Hunt'], lambda{|rec| rec.name =~ /Andy/i}
    assert_equal ['Mr. Hunt', 'DAVE THOMAS'], tbl.select.map{|r| r.name}

    Author.update_all ['name = ?', 'Dave'], ['name = ?', 'DAVE THOMAS']
    assert_equal ['Mr. Hunt', 'Dave'], tbl.select.map{|r| r.name}

    # We can handle simple SQL fragments in conditions
    Author.update_all ['num_books = ?', 1], "name = 'Dave'"
    assert_equal ['Mr. Hunt', 'Dave'], tbl.select.map{|r| r.name}
    assert_equal [0, 1], tbl.select.map{|r| r.num_books}
    
    assert_nothing_raised { Author.update_all ['name = ?', 'Dave Thomas'], "name = 'Dave' and num_books = 1" }
    assert_equal ['Mr. Hunt', 'Dave Thomas'], tbl.select.map{|r| r.name}
    
    Author.update_all ['name = ?', 'Pragmatic']
    assert_equal ['Pragmatic', 'Pragmatic'], tbl.select.map{|r| r.name}

    # Check updates of non-strings
    tbl.drop_column :num_books rescue nil
    tbl.add_column :num_books, :Integer

    Author.update_all ['num_books = ?', 1]
    assert_equal [1, 1], tbl.select.map{|r| r.num_books}

    Author.update_all "num_books = 2"
    assert_equal [2, 2], tbl.select.map{|r| r.num_books}
  end
  
  def test_destroy
    authors = $db.get_table(:authors)
    assert_equal 2, authors.total_recs
    assert_equal 2, Author.find(:all).size
    # class level destroy
    Author.destroy(1)
    assert_equal 1, authors.total_recs
    assert_equal 1, Author.find(:all).size
    # object destroy
    Author.find(:first).destroy
    assert_equal 0, authors.total_recs
    assert_equal 0, Author.find(:all).size
    assert_raise(ActiveRecord::RecordNotFound) { Author.find(1) }

    pages = $db.get_table(:pages)
    assert_equal 5, pages.total_recs
    Page.destroy [1,2,3]
    assert_equal 2, pages.total_recs
    Page.destroy [4,5]
    assert_equal 0, pages.total_recs
    assert_raise(ActiveRecord::RecordNotFound) { Page.destroy(1) }
  end

  def test_increment_counter
    tbl = $db.get_table(:authors)
    tbl.drop_column :num_books rescue nil
    tbl.add_column :num_books, { :DataType => :Integer, :Default => 0 }
    tbl.update_all :num_books => 1

    assert_equal [1, 1], tbl.select.map{|a| a.num_books}
    assert_equal [1, 1], Author.find(:all).map{|a| a.num_books}

    Author.increment_counter 'num_books', 1
    assert_equal [2, 1], tbl.select.map{|r| r.num_books}

    Author.increment_counter 'num_books', [1, 2]
    assert_equal [3, 2], tbl.select.map{|r| r.num_books}
  end

  def test_decrement_counter
    tbl = $db.get_table(:authors)
    tbl.drop_column :num_books rescue nil
    tbl.add_column :num_books, { :DataType => :Integer, :Default => 2 }
    tbl.update_all :num_books => 2

    assert_equal [2, 2], tbl.select.map{|a| a.num_books}
    assert_equal [2, 2], Author.find(:all).map{|a| a.num_books}

    Author.decrement_counter 'num_books', 1
    assert_equal [1, 2], tbl.select.map{|r| r.num_books}

    Author.decrement_counter 'num_books', [1, 2]
    assert_equal [0, 1], tbl.select.map{|r| r.num_books}
  end

  def test_count
    assert_equal 2, Author.count
    assert_equal 1, Author.count {|rec| rec.name =~ /Andy/}
    assert_equal 1, Author.count("name = 'Dave Thomas'")
    assert_equal 1, Author.count(["name = ?", 'Dave Thomas'])
    assert_equal 2, Author.count(nil)
  end

  def test_ruby_code_in_conditionals
    DateAndTimeTests.table.insert( Date.new(2005, 1, 1), 1.day.ago )
    records = []
    
    assert_nothing_raised { records = DateAndTimeTests.find :all, :conditions => 'date_value > Date.today' }
    assert_equal 0, records.length
    
    assert_nothing_raised { records = DateAndTimeTests.find :all, :conditions => 'date_value > Date.new(2004-1-1)' }
    assert_equal 1, records.length
    
    assert_nothing_raised { records = DateAndTimeTests.find :all, :conditions => 'time_value > Time.now' }
    assert_equal 0, records.length
    
    assert_nothing_raised { records = DateAndTimeTests.find :all, :conditions => 'time_value < Time.now' }
    assert_equal 1, records.length

    class << Object
      def now() Time.now end
    end

    assert_nothing_raised { records = DateAndTimeTests.find :all, :conditions => 'time_value > now' }
    assert_equal 0, records.length
    
    assert_nothing_raised { records = DateAndTimeTests.find :all, :conditions => 'time_value < now' }
    assert_equal 1, records.length

  end

  def test_nil_values
    NilTest.table.insert(nil, 100)
    records = []

    assert_nothing_raised { records = NilTest.find :all, :conditions => lambda{|rec| rec.nil_value > 100} }
    assert_equal 0, records.length

    assert_nothing_raised { records = NilTest.find :all, :conditions => lambda{|rec| rec.nil_value > 100 and rec.conditional > 100} }
    assert_equal 0, records.length

    assert_nothing_raised { records = NilTest.find :all, :conditions => lambda{|rec| rec.nil_value > 100 or rec.conditional == 100} }
    assert_equal 1, records.length

    assert_nothing_raised { records = NilTest.find :all, :conditions => 'nil_value > 100' }
    assert_equal 0, records.length

    assert_nothing_raised { records = NilTest.find :all, :conditions => 'nil_value > 100 and conditional > 100' }
    assert_equal 0, records.length

    assert_nothing_raised { records = NilTest.find :all, :conditions => 'nil_value > 100 and conditional = 100' }
    assert_equal 0, records.length

    assert_nothing_raised { records = NilTest.find :all, :conditions => 'nil_value > 100 or conditional = 100' }
    assert_equal 1, records.length

    assert_nothing_raised { records = NilTest.find :all, :conditions => 'nil_value > 100 or conditional > 100' }
    assert_equal 0, records.length
  end
end