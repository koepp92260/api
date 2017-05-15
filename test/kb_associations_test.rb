require 'test_helper'

class KBAssociationsTest < Test::Unit::TestCase

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

  def test_has_one
    @err = Errata.create :book_id => 1, :contents => 'page 1: no text'

    assert_equal @pickaxe, Errata.find(:first).book
    assert_equal @err, Book.find(:first).errata

    @cvs = Book.create :name => 'Pragmatic CVS', :published => 1.year.ago.to_date, :publisher => @pragprogs
    @err = Errata.create :book => @cvs, :contents => 'use SVN'
    @cvs.reload; @err.reload
    assert_equal @cvs, Errata.find(:first, :conditions => lambda{|r| r.book_id == @cvs.id}).book
    assert_equal @err, Book.find(:first, :conditions => lambda{|r| r.name =~ /CVS/}).errata
  end

  def test_belongs_to
    @cvs = Book.create :publisher_id => @pragprog.id, :name => 'Pragmatic CVS', :published => Date.today
    assert_equal @pragprog, @cvs.publisher
    assert_equal @pragprog.id, $db.get_table(:books).select{|b|b.name =~ /CVS/}[0].publisher_id

    @svn = Book.create :publisher => @pragprog, :name => 'Pragmatic SVN', :published => Date.today
    assert_equal @pragprog, @svn.publisher
    assert_equal @pragprog.id, $db.get_table(:books).select{|b|b.name =~ /SVN/}[0].publisher_id
    
    assert_equal @pragprog.id, $db.get_table(:books).select{|b| b.name =~ /ruby/i}[0].publisher_id
    book = Book.find(:first) {|b| b.name =~ /ruby/i}
    assert_equal @pickaxe, book
    assert_equal @pragprog, book.publisher
    
    book.publisher = nil
    book.save
    
    assert_equal nil, $db.get_table(:books).select{|b|b.name =~ /ruby/i}[0].publisher_id
    assert_equal nil, book.publisher
    assert_equal nil, Book.find(:first).publisher
  end

  def test_has_many
    assert_equal 5, Book.find(:first).pages.size
    assert_equal [@front, @chap1, @chap2, @annex, @back].sort_by(:id), @pickaxe.pages.sort_by(:id)
    
    assert_equal [@chap1, @chap2].sort_by(:id), @pickaxe.pages.find(:all, :conditions => lambda{|rec| rec.book_id == @pickaxe.id and rec.content =~ /text/}).sort_by(:id)
  end

  def test_has_many_destroy_dependents
    book = Book.create :name => 'pulp fiction', :published => Date.today
    page1 = Page.create :book => book, :page_num => 1, :content => 'text 1'
    page2 = Page.create :book => book, :page_num => 2, :content => 'text 2'
    page3 = Page.create :book => book, :page_num => 3, :content => 'text 3'

    book.pages << page1
    book.pages << [page2, page3]
    assert_equal 2, book.id

    assert_equal 2, Book.find(:all).size
    assert_equal 8, Page.find(:all).size
    assert_equal 5, Book.find(1).pages.size
    assert_equal 3, Book.find(2).pages.size
    
    Book.destroy(2)
    assert_raise(ActiveRecord::RecordNotFound) { Book.find(2) }
    assert_raise(ActiveRecord::RecordNotFound) { Page.find(page1.id) }
    assert_raise(ActiveRecord::RecordNotFound) { Page.find(page2.id) }
    assert_raise(ActiveRecord::RecordNotFound) { Page.find(page3.id) }

    assert_equal 1, Book.find(:all).size
    assert_equal 5, Page.find(:all).size
    assert_equal 5, Book.find(1).pages.size
  end

  def test_has_and_belongs_to_many
    assert_equal 2, $db.get_table(:authors_books).select.size
    assert_equal [@andy, @dave], @pickaxe.author
    assert_equal 2, @pickaxe.author.size

    assert_equal [@pickaxe], @andy.book
    assert_equal [@pickaxe], @dave.book
    assert_equal 1, @andy.book.size
    assert_equal 1, @dave.book.size

    @cvs = Book.create :publisher_id => @pragprog.id, :name => 'Pragmatic CVS', :published => Date.today
    @cvs.author << @andy
    @svn = Book.create :publisher => @pragprog, :name => 'Pragmatic SVN', :published => Date.today
    @svn.author << @dave

    assert_equal [@andy], @cvs.author
    assert_equal [@dave], @svn.author
    @andy.reload; @dave.reload
    assert_equal [@pickaxe, @cvs], @andy.book
    assert_equal [@pickaxe, @svn], @dave.book
  end
end
