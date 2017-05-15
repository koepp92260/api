require 'test_helper'

## This class checks only the translate_sql_to_code method
class KBStdlibExtensionsTest < Test::Unit::TestCase

  def setup
    @num_array = [2,4,6,3,5,1]
    @string_array = ['az', 'cx', 'by', 'dw']
    @rec_array = [['c', 2], ['a', 2], ['d', 1], ['b', 1]]
  end
  
  def test_array_sort_by
    assert_equal [1,2,3,4,5,6], @num_array.sort_by(:to_i)
    assert_equal [1,2,3,4,5,6], @num_array.sort_by{|x| x.to_i}
    assert_equal ['dw', 'cx', 'by', 'az'], @string_array.sort_by(:reverse)
    assert_equal ['az', 'by', 'cx', 'dw'], @string_array.sort_by{|x| x[0..0]}
  end
  
  def test_array_sort_by!
    @num_array.sort_by!(:to_i)
    assert_equal [1,2,3,4,5,6], @num_array
  end

  def test_array_stable_sort
    assert_equal [['a', 2], ['b', 1], ['c', 2], ['d', 1]], @rec_array.stable_sort
  end

  def test_array_stable_sort_by
    assert_equal [['d', 1], ['b', 1], ['c', 2], ['a', 2]], @rec_array.stable_sort_by(:last)
  end

  def test_object_in
    assert 1.in(@num_array)
    assert !1.in(@string_array)
    assert 1.in(1)
    assert 1.in(1,2,3)
  end
end
