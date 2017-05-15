require 'test_helper'

## This class checks only the translate_sql_to_code method
class KBSqlToCodeTest < Test::Unit::TestCase

  def test_basic
    assert_equal "rec.name == ?", Book.translate_sql_to_code("name = ?")
    assert_equal "rec.name == 'Andy Hunt'", Book.translate_sql_to_code("name = 'Andy Hunt'")
    assert_equal "rec.parent_id == 1", Book.translate_sql_to_code("parent_id = 1")
    assert_equal "rec.name == ?", Book.translate_sql_to_code("name = ?")
    assert_equal "rec.name == ?", Book.translate_sql_to_code("name = :name")
    assert_equal "rec.name == ?", Book.translate_sql_to_code("name = '%s'")
    assert_equal "true", Book.translate_sql_to_code("1 = 1")
    assert_equal "rec.type == 'Client'", Book.translate_sql_to_code("type = 'Client'")
  end

  def test_comparison_operators
    assert_equal "rec.salary > 90000", Book.translate_sql_to_code("salary > 90000")
    assert_equal "rec.salary < 90000", Book.translate_sql_to_code("salary < 90000")
    assert_equal "rec.salary >= 90000", Book.translate_sql_to_code("salary >= 90000")
    assert_equal "rec.salary <= 90000", Book.translate_sql_to_code("salary <= 90000")
    assert_equal "rec.salary != 90000", Book.translate_sql_to_code("salary <> 90000")
    assert_equal "rec.recno > 5", Book.translate_sql_to_code("id > 5")
    assert_equal "rec.recno < 5", Book.translate_sql_to_code("id < 5")
    assert_equal "rec.recno >= 5", Book.translate_sql_to_code("id >= 5")
    assert_equal "rec.recno <= 5", Book.translate_sql_to_code("id <= 5")
    assert_equal "rec.recno != 5", Book.translate_sql_to_code("id <> 5")
  end

  def test_id_to_recno
    assert_equal "rec.recno == ?", Book.translate_sql_to_code("id = ?")
    assert_equal "rec.recno == ? and rec.name == ?", Book.translate_sql_to_code("id=? AND name = ?")
    assert_equal "rec.recno == ?", Book.translate_sql_to_code("id=?")
    assert_equal "rec.recno == ?", Book.translate_sql_to_code("id = %d")
    assert_equal "rec.recno > 3", Book.translate_sql_to_code("id > 3")
    assert_equal "rec.recno > 3", Book.translate_sql_to_code("rec.recno > 3")
    assert_equal "rec.recno > ?", Book.translate_sql_to_code("id > ?")
  end

  def test_and_or
    assert_equal "rec.book_id == ? and rec.content == ?", Book.translate_sql_to_code("book_id = ? AND content = ?")
    assert_equal "rec.name == 'Dave' and rec.num_books == 1", Book.translate_sql_to_code("name = 'Dave' AND num_books = 1")

    assert_equal "rec.book_id == ? or rec.content == ?", Book.translate_sql_to_code("book_id = ? OR content = ?")
    assert_equal "rec.name == 'Dave' or rec.num_books == 1", Book.translate_sql_to_code("name = 'Dave' OR num_books = 1")

    assert_equal "rec.book_id == ? and (rec.name == ? or rec.content == ?)", Book.translate_sql_to_code("book_id = ? AND (name = ? OR content = ?)")
    assert_equal "rec.recno > ? or (rec.name == ? and rec.content == ?)", Book.translate_sql_to_code("id > ? OR (name = ? AND content = ?)")

    assert_equal "rec.recno == ? and rec.name == ?", Book.translate_sql_to_code("id=:id and name=:name")
  end
  
  def test_is
    assert_equal "rec.last_read == ?", Book.translate_sql_to_code("last_read IS ?")
    assert_equal "rec.last_read == ?  and rec.author_name == ?", Book.translate_sql_to_code("last_read IS ?  and author_name = ?")
  end

  def test_null
    assert_equal "rec.last_read == nil", Book.translate_sql_to_code("last_read IS NULL")
    assert_equal "rec.last_read != nil", Book.translate_sql_to_code("last_read IS NOT NULL")
  end
  
  def test_in
    assert_equal "rec.title.in(?)", Book.translate_sql_to_code("title IN (?)")
    assert_equal "rec.recno.in(1, 2, 3)", Book.translate_sql_to_code("id IN (1, 2, 3)")
    assert_equal "rec.recno.in(1,2, 3  )", Book.translate_sql_to_code("id IN (1,2, 3  )")
    assert_equal "rec.name.in('me', 'you')", Book.translate_sql_to_code("name IN ('me', 'you')")
  end

  def test_preserve_rec
    assert_equal "rec.name == ?", Book.translate_sql_to_code("rec.name == ?")
    assert_equal "rec.name == 'John'", Book.translate_sql_to_code("rec.name == 'John'")
    assert_equal "rec.recno > 3", Book.translate_sql_to_code("rec.recno > 3")
    assert_equal "rec.recno < 3", Book.translate_sql_to_code("rec.recno < 3")
    assert_equal "rec.recno >= 3", Book.translate_sql_to_code("rec.recno >= 3")
    assert_equal "rec.recno <= 3", Book.translate_sql_to_code("rec.recno <= 3")
  end

end
