print "Using native KirbyBase\n"
require_dependency 'fixtures/course'
require 'logger'
require 'create_dbs_for_ar_tests'

db1_path = File.expand_path File.join(File.dirname(__FILE__), 'db/activerecord_unittest') 
db2_path = File.expand_path File.join(File.dirname(__FILE__), 'db/activerecord_unittest2')

[db1_path, db2_path].each_with_index do |path, idx|
  FileUtils.rm_rf(path) rescue nil
  FileUtils.mkdir(path) rescue Errno::EEXIST nil
end

db = KirbyBase.new :local, nil, nil, db1_path
create_and_init db
db2 = KirbyBase.new :local, nil, nil, db2_path
create_and_init_2 db2

ActiveRecord::Base.establish_connection(
  :adapter  => "kirbybase",
  :database => db1_path
)

Course.establish_connection(
  :adapter  => "kirbybase",
  :database => db2_path
)
