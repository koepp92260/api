class Book < ActiveRecord::Base
  belongs_to :publisher
  has_many :pages, :dependent => true
  has_one :errata
  has_and_belongs_to_many :author
end

class Page < ActiveRecord::Base
  belongs_to :book
end

class Author < ActiveRecord::Base
  has_and_belongs_to_many :book
end

class Publisher < ActiveRecord::Base
  has_many :books
end

class Errata < ActiveRecord::Base
  set_table_name 'errata'
  belongs_to :book
end

class PrimaryKeyTest < ActiveRecord::Base
  set_primary_key :pk
end

class NilTest < ActiveRecord::Base
end

class DateAndTimeTests < ActiveRecord::Base
end