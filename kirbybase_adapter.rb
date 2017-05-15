require 'kirbybase'
require_gem 'rails'
require 'active_record'
require 'active_record/connection_adapters/abstract_adapter'

module ActiveRecord
  ##############################################################################
  # Define the KirbyBase connection establishment method

  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.kirbybase_connection(config) # :nodoc:
      # Load the KirbyBase DBMS
      unless self.class.const_defined?(:KirbyBase)
        begin
          require 'kirbybase'
        rescue LoadError
          raise "Unable to load KirbyBase"
        end
      end

      config = config.symbolize_keys
      connection_type = config[:connection_type] || config[:conn_type]
      connection_type =  if connection_type.nil? or connection_type.empty?
                           :local
                         else
                           connection_type.to_sym
                         end
      host     = config[:host]
      port     = config[:port]
      path     = config[:dbpath] || config[:database] || File.join(RAILS_ROOT, 'db/data')

      # ActiveRecord::Base.allow_concurrency = false if connection_type == :local
      ConnectionAdapters::KirbyBaseAdapter.new(connection_type, host, port, path)
    end
  end

  ##############################################################################
  # Define the KirbyBase adapter and column classes
  module ConnectionAdapters
    class KirbyBaseColumn < Column
      def initialize(name, default, sql_type = nil, null = true)
        super
        @name = (name == 'recno' ? 'id' : @name)
        @text = [:string, :text, :yaml].include? @type
      end

      def simplified_type(field_type)
        case field_type
          when /int/i
            :integer
          when /float|double|decimal|numeric/i
            :float
          when /datetime/i
            :datetime
          when /timestamp/i
            :timestamp
          when /time/i
            :datetime
          when /date/i
            :date
          when /clob/i, /text/i
            :text
          when /blob/i, /binary/i
            :binary
          when /char/i, /string/i
            :string
          when /boolean/i
            :boolean
          when /yaml/i
            :yaml
          else
            field_type.to_sym
        end
      end

      def self.string_to_time(string)
        super or string_to_dummy_time(string)
      end
    end

    # The KirbyBase adapter does not need a "db driver", as KirbyBase is a
    # pure-ruby DBMS. This adapter defines all the required functionality by
    # executing direct method calls on a KirbyBase DB object.
    #
    # Options (for database.yml):
    #
    # * <tt>:connection_type</tt> -- type of connection (local or client). Defaults to :local
    # * <tt>:host</tt> -- If using KirbyBase in a client/server mode
    # * <tt>:port</tt> -- If using KirbyBase in a client/server mode
    # * <tt>:path</tt> -- Path to DB storage area. Defaults to /db/data
    #
    # *Note* that Ackbar/KirbyBase support migrations/schema but not transactions.
    class KirbyBaseAdapter < AbstractAdapter

      # Ackbar's own version - i.e. the adapter version, not KirbyBase or Rails.
      VERSION = '0.1.1'

      attr_accessor :db

      def initialize(connect_type, host, port, path)
        if connect_type == :local
          FileUtils.mkdir_p(path) unless File.exists?(path)
        end
        @db = KirbyBase.new(connect_type, host, port, path)
      end

      def adapter_name
        'KirbyBase'
      end

      def supports_migrations?
        true
      end

      PRIMARY_KEY_TYPE = { :Calculated => 'recno', :DataType => :Integer }
      def PRIMARY_KEY_TYPE.to_sym() :integer end

      # Translates all the ActiveRecord simplified SQL types to KirbyBase (Ruby)
      # Types. Also allows KB specific types like :YAML.
      def native_database_types #:nodoc
        {
          :primary_key => PRIMARY_KEY_TYPE,
          :string      => { :DataType => :String },
          :text        => { :DataType => :String }, # are KBMemos better?
          :integer     => { :DataType => :Integer },
          :float       => { :DataType => :Float },
          :datetime    => { :DataType => :Time },
          :timestamp   => { :DataType => :Time },
          :time        => { :DataType => :Time },
          :date        => { :DataType => :Date },
          :binary      => { :DataType => :String },  # are KBBlobs better?
          :boolean     => { :DataType => :Boolean },
          :yaml        => { :DataType => :YAML }
        }
      end

      # NOT SUPPORTED !!!
      def execute(*params)
        raise ArgumentError, "SQL not supported! (#{params.inspect})" unless block_given?
        yield db
      end

      # NOT SUPPORTED !!!
      def update(*params)
        raise ArgumentError, "SQL not supported! (#{params.inspect})" unless block_given?
        yield db
      end

      # Returns a handle on a KBTable object
      def get_table(table_name)
        db.get_table(table_name.to_sym)
      end



      def create_table(name, options = {})
        table_definition = TableDefinition.new(self)
        table_definition.primary_key(options[:primary_key] || "id") unless options[:id] == false

        yield table_definition

        if options[:force]
          drop_table(name) rescue nil
        end

        # Todo: Handle temporary tables (options[:temporary]), creation options (options[:options])
        defns = table_definition.columns.inject([]) do |defns, col|
          if col.type == PRIMARY_KEY_TYPE
            defns
          else
            kb_col_options = native_database_types[col.type]
            kb_col_options = kb_col_options.merge({ :Required => true }) if not col.null.nil? and not col.null
            kb_col_options = kb_col_options.merge({ :Default => col.default }) unless col.default.nil?
            kb_col_options[:Default] = true if kb_col_options[:DataType] == :Boolean && kb_col_options[:Default]
            # the :limit option is ignored - meaningless considering the ruby types and KB storage
            defns << [col.name.to_sym, kb_col_options]
          end
        end
        begin
          db.create_table(name.to_sym, *defns.flatten)
        rescue => detail
          raise "Create table '#{name}' failed: #{detail}"
        end
      end

      def drop_table(table_name)
        db.drop_table(table_name.to_sym)
      end

      def initialize_schema_information
        begin
          schema_info_table = create_table(ActiveRecord::Migrator.schema_info_table_name.to_sym) do |t|
            t.column :version, :integer
          end
          schema_info_table.insert(0)
        rescue ActiveRecord::StatementInvalid, RuntimeError
          # RuntimeError is raised by KB if the table already exists
          # Schema has been intialized
        end
      end

      def tables(name = nil)
        db.tables.map {|t| t.to_s}
      end

      def columns(table_name, name=nil)
        tbl = db.get_table(table_name.to_sym)
        tbl.field_names.zip(tbl.field_defaults, tbl.field_types, tbl.field_requireds).map do |fname, fdefault, ftype, frequired|
          KirbyBaseColumn.new(fname.to_s, fdefault, ftype.to_s.downcase, !frequired)
        end
      end

      def indexes(table_name, name = nil)
        table = db.get_table(table_name.to_sym)
        indices = table.field_names.zip(table.field_indexes)
        indices_to_columns = indices.inject(Hash.new{|h,k| h[k] = Array.new}) {|hsh, (fn, ind)| hsh[ind] << fn.to_s unless ind.nil?; hsh}
        indices_to_columns.map do |ind, cols|
          # we're not keeping the names anywhere (KB doesn't store them), so we
          # just give the default name
          IndexDefinition.new(table_name, "#{table_name}_#{cols[0]}_index", false, cols)
        end
      end

      def primary_key(table_name)
        raise ArgumentError, "#primary_key called"
        column = table_structure(table_name).find {|field| field['pk'].to_i == 1}
        column ? column['name'] : nil
      end

      def add_index(table_name, column_name, options = {})
        db.get_table(table_name.to_sym).add_index( *Array(column_name).map{|c| c.to_sym} )
      end

      def remove_index(table_name, options={})
        db.get_table(table_name.to_sym).drop_index(options) rescue nil
      end

      def rename_table(name, new_name)
        db.rename_table(name.to_sym, new_name.to_sym)
      end

      def add_column(table_name, column_name, type, options = {})
        type = type.is_a?(Hash)? type : native_database_types[type]
        type.merge!({:Required => true}) if options[:null] == false
        type.merge!({:Default => options[:default]}) if options.has_key?(:default)
        if type[:DataType] == :Boolean && type.has_key?(:Default)
          type[:Default] = case type[:Default]
            when true, false, nil then type[:Default]
            when String  then type[:Default] == 't' ? true : false
            when Integer then type[:Default] ==  1  ? true : false
          end
        end
        db.get_table(table_name.to_sym).add_column(column_name.to_sym, type)
      end

      def remove_column(table_name, column_name)
        db.get_table(table_name.to_sym).drop_column(column_name.to_sym)
      end

      def change_column_default(table_name, column_name, default)
        column_name = column_name.to_sym
        tbl = db.get_table(table_name.to_sym)
        if columns(table_name.to_sym).detect{|col| col.name.to_sym == column_name}.type == :boolean
          default = case default
            when true, false, nil then default
            when String  then default == 't' ? true : false
            when Integer then default ==  1  ? true : false
          end
        end
        tbl.change_column_default_value(column_name.to_sym, default)
      end

      def change_column(table_name, column_name, type, options = {})
        column_name = column_name.to_sym
        tbl = db.get_table(table_name.to_sym)
        tbl.change_column_type(column_name, native_database_types[type][:DataType])
        tbl.change_column_required(column_name, options[:null] == false)
        if options.has_key?(:default)
          change_column_default(table_name, column_name, options[:default])
        end
      end

      def rename_column(table_name, column_name, new_column_name)
        db.get_table(table_name.to_sym).rename_column(column_name.to_sym, new_column_name.to_sym)
      end
    end
  end

  ##############################################################################
  # CLASS METHODS: Override SQL based methods in ActiveRecord::Base
  # Class methods: everything invoked from records classes, e.g. Book.find(:all)

  class Base
    # Utilities ################################################################

    # The KirbyBase object
    def self.db
      #db ||= connection.db
      connection.db
    end

    # The KBTable object for this AR model object
    def self.table
      begin
        db.get_table(table_name.to_sym)
      rescue RuntimeError => detail
        raise StatementInvalid, detail.message
      end
    end

    # NOT SUPPORTED !!!
    def self.select_all(sql, name = nil)
      raise StatementInvalid, "select_all(#{sql}, #{name}"
      execute(sql, name).map do |row|
        record = {}
        row.each_key do |key|
          if key.is_a?(String)
            record[key.sub(/^\w+\./, '')] = row[key]
          end
        end
        record
      end
    end

    # NOT SUPPORTED !!!
    def self.select_one(sql, name = nil)
      raise StatementInvalid, "select_one(#{sql}, #{name}"
      result = select_all(sql, name)
      result.nil? ? nil : result.first
    end

    # NOT SUPPORTED !!!
    def self.find_by_sql(*args)
      raise StatementInvalid, "SQL not Supported"
    end

    # NOT SUPPORTED !!!
    def self.count_by_sql(*args)
      raise StatementInvalid, "SQL not Supported"
    end

    # Deletes the selected rows from the DB.
    def self.delete(ids)
      ids = [ids].flatten
      table.delete {|r| ids.include? r.recno }
    end

    # Deletes the matching rows from the table. If no conditions are specified,
    # will clear the whole table.
    def self.delete_all(conditions = nil)
      if conditions.nil? and !block_given?
        table.delete_all
      else
        table.delete &build_conditions_from_options(:conditions => conditions)
      end
    end

    # Updates the matching rows from the table. If no conditions are specified,
    # will update all rows in the table.
    def self.update_all(updates, conditions = nil)
      finder = build_conditions_from_options :conditions => conditions
      updater = case updates
                 when Proc   then updates
                 when Hash   then updates
                 when Array  then parse_updates_from_sql_array(updates)
                 when String then parse_updates_from_sql_string(updates)
                 else        raise ArgumentError, "Don't know how to process updates: #{updates.inspect}"
                end
      updater.is_a?(Proc) ?
        table.update(&finder).set(&updater) :
        table.update(&finder).set(updater)
    end

    # Attempt to parse parameters in the format of ['name = ?', some_name] for updates
    def self.parse_updates_from_sql_array sql_parameters_array
      updates_string = sql_parameters_array[0]
      args = sql_parameters_array[1..-1]

      update_code = table.field_names.inject(updates_string) {|updates, fld| fld == :id ? updates.gsub(/\bid\b/, 'rec.recno') : updates.gsub(/\b(#{fld})\b/, 'rec.\1') }
      update_code = update_code.split(',').zip(args).map {|i,v| [i.gsub('?', ''), v.inspect]}.to_s.gsub(/\bNULL\b/i, 'nil')
      eval "lambda{ |rec| #{update_code} }"
    end

    # Attempt to parse parameters in the format of 'name = "Some Name"' for updates
    def self.parse_updates_from_sql_string sql_string
      update_code = table.field_names.inject(sql_string) {|updates, fld| fld == :id ? updates.gsub(/\bid\b/, 'rec.recno') : updates.gsub(/\b(#{fld})\b/, 'rec.\1') }.gsub(/\bNULL\b/i, 'nil')
      eval "lambda{ |rec| #{update_code} }"
    end

    # Attempt to parse parameters in the format of ['name = ? AND value = ?', some_name, 1]
    # in the :conditions clause
    def self.parse_conditions_from_sql_array(sql_parameters_array)
      query = sql_parameters_array[0]
      args = sql_parameters_array[1..-1].map{|arg| arg.is_a?(Hash) ? (raise PreparedStatementInvalid if arg.size > 1; arg.values[0]) : arg }

      query = translate_sql_to_code query
      raise PreparedStatementInvalid if query.count('?') != args.size
      query_components = query.split('?').zip(args.map{ |a|
        case a
        when String, Array  then a.inspect
        when nil            then 'nil'
        else a
        end
      })
      block_string = query_components.to_s
      begin
        eval "lambda{ |rec| #{block_string} }"
      rescue Exception => detail
        raise PreparedStatementInvalid, detail.to_s
      end
    end

    # Override of AR::Base SQL construction to build a conditions block. Used only
    # by AR::Base#method_missing to support dynamic finders (e.g. find_by_name).
    def self.construct_conditions_from_arguments(attribute_names, arguments)
      conditions = []
      attribute_names.each_with_index { |name, idx| conditions << "#{name} #{attribute_condition(arguments[idx])} " }
      build_conditions_from_options :conditions => [ conditions.join(" and ").strip, *arguments[0...attribute_names.length] ]
    end

    # Override of AR::Base that was using raw SQL
    def self.increment_counter(counter_name, ids)
      [ids].flatten.each do |id|
        table.update{|rec| rec.recno == id }.set{ |rec| rec.send "#{counter_name}=", (rec.send(counter_name)+1) }
      end
    end

    # Override of AR::Base that was using raw SQL
    def self.decrement_counter(counter_name, ids)
      [ids].flatten.each do |id|
        table.update{|rec| rec.recno == id }.set{ |rec| rec.send "#{counter_name}=", (rec.send(counter_name)-1) }
      end
    end

    # This methods differs in the API from ActiveRecord::Base#find!
    # The changed options are:
    # * <tt>:conditions</tt> this should be a block for selecting the records
    # * <tt>:order</tt> this should be the symbol of the field name
    # * <tt>:include</tt>: Names associations that should be loaded alongside using KirbyBase Lookup fields
    # The following work as before:
    # * <tt>:offset</tt>: An integer determining the offset from where the rows should be fetched. So at 5, it would skip the first 4 rows.
    # * <tt>:readonly</tt>: Mark the returned records read-only so they cannot be saved or updated.
    # * <tt>:limit</tt>: Max numer of records returned
    # * <tt>:select</tt>: Field names from the table. Not as useful, as joins are irrelevant
    # The following are not supported (silently ignored);
    # * <tt>:joins</tt>: An SQL fragment for additional joins like "LEFT JOIN comments ON comments.post_id = id".
    #
    # As a more Kirby-ish way, you can also pass a block to #find that will be
    # used to select the matching records. It's a shortcut to :conditions.
    def self.find(*args)
      options = extract_options_from_args!(args)
      conditions = Proc.new if block_given?
      raise ArgumentError, "Please specify EITHER :conditions OR a block!" if conditions and options[:conditions]
      options[:conditions] ||= conditions
      options[:conditions] = build_conditions_from_options(options)
      filter = options[:select] ? [:recno, options[:select]].flatten.map{|s| s.to_sym} : nil

      # Inherit :readonly from finder scope if set.  Otherwise,
      # if :joins is not blank then :readonly defaults to true.
      unless options.has_key?(:readonly)
        if scoped?(:find, :readonly)
          options[:readonly] = scope(:find, :readonly)
        elsif !options[:joins].blank?
          options[:readonly] = true
        end
      end

      case args.first
      when :first
        return find(:all, options.merge(options[:include] ? { } : { :limit => 1 })).first
      when :all
        records = options[:include] ?
                    find_with_associations(options) :
                    filter ? table.select( *filter, &options[:conditions] ) : table.select( &options[:conditions] )
        records = apply_options_to_result_set records, options
        records = instantiate_records(records, :filter => filter, :readonly => options[:readonly])
        records
      else
        return args.first if args.first.kind_of?(Array) && args.first.empty?
        raise RecordNotFound, "Expecting a list of IDs!" unless args.flatten.all?{|i| i.is_a?(Numeric) || (i.is_a?(String) && i.match(/^\d+$/)) }

        expects_array = ( args.is_a?(Array) and args.first.kind_of?(Array) )
        ids = args.flatten.compact.collect{ |i| i.to_i }.uniq

        records = filter ?
                    table.select_by_recno_index(*filter) { |r| ids.include?(r.recno) } :
                    table.select_by_recno_index { |r| ids.include?(r.recno) }
        records = apply_options_to_result_set(records, options) rescue records

        conditions_message = options[:conditions] ? " and conditions: #{options[:conditions].inspect}" : ''
        case ids.size
          when 0
            raise RecordNotFound, "Couldn't find #{name} without an ID#{conditions_message}"
          when 1
            if records.nil? or records.empty?
              raise RecordNotFound, "Couldn't find #{name} with ID=#{ids.first}#{conditions_message}"
            end
            records = instantiate_records(records, :filter => filter, :readonly => options[:readonly])
            expects_array ? records : records.first
          else
            if records.size == ids.size
              return instantiate_records(records, :filter => filter, :readonly => options[:readonly])
            else
              raise RecordNotFound, "Couldn't find all #{name.pluralize} with IDs (#{ids.join(', ')})#{conditions_message}"
            end
        end
      end
    end

    # Instantiates the model record-objects from the KirbyBase structs.
    # Will also apply the limit/offset/readonly/order and other options.
    def self.instantiate_records rec_array, options = {}
      field_names = ['id', table.field_names[1..-1]].flatten.map { |f| f.to_s }
      field_names &= ['id', options[:filter]].flatten.map{|f| f.to_s} if options[:filter]
      records = [rec_array].flatten.compact.map { |rec| instantiate( field_names.zip(rec.values).inject({}){|h, (k,v)| h[k] = v; h} ) }
      records.each { |record| record.readonly! } if options[:readonly]
      records
    end

    
    # Applies the limit/offset/readonly/order and other options to the result set.
    # Will also reapply the conditions.
    def self.apply_options_to_result_set records, options
      records = [records].flatten.compact
      records = records.select( &options[:conditions] ) if options[:conditions]
      if options[:order]
        options[:order].split(',').reverse.each do |order_field|
          # this algorithm is probably incorrect for complex sorts, like
          # col_a, col_b DESC, col_C
          reverse = order_field =~ /\bDESC\b/i
          order_field = order_field.strip.split[0] # clear any DESC, ASC
          records = records.stable_sort_by(order_field.to_sym == :id ? :recno : order_field.to_sym)
          records.reverse! if reverse
        end
      end
      offset = options[:offset] || scope(:find, :offset)
      records = records.slice!(offset..-1) if offset
      limit = options[:limit] || scope(:find, :limit)
      records = records.slice!(0, limit) if limit
      records
    end

    private_class_method :instantiate_records, :apply_options_to_result_set

    # One of the main methods: Assembles the :conditions block from the
    # options argument (See build_conditions_block for actual translation). Then
    # adds the scope and inheritance-type conditions (if present).
    def self.build_conditions_from_options options
      basic_selector_block = case options
        when Array
          if options[0].is_a? Proc
            options[0]
          elsif options.flatten.length == 1
            translate_sql_to_code options.flatten[0]
          else
            parse_conditions_from_sql_array options.flatten
          end

        when Hash
          build_conditions_block options[:conditions]

        when Proc
          options

        else
          raise ArgumentError, "Don't know how to process (#{options.inspect})"
      end

      selector_with_scope = if scope(:find, :conditions)
        scope_conditions_block = build_conditions_block(scope(:find, :conditions))
        lambda{|rec| basic_selector_block[rec] && scope_conditions_block[rec]}
      else
        basic_selector_block
      end

      conditions_block = if descends_from_active_record?
        selector_with_scope
      else
        untyped_conditions_block = selector_with_scope
        type_condition_block = type_condition(options.is_a?(Hash) ? options[:class_name] : nil)
        lambda{|rec| type_condition_block[rec] && untyped_conditions_block[rec]}
      end

      conditions_block
    end

    # For handling the table inheritance column.
    def self.type_condition class_name = nil
      type_condition = if class_name
        "rec.#{inheritance_column} == '#{class_name}'"
      else
        subclasses.inject("rec.#{inheritance_column}.to_s == '#{name.demodulize}' ") do |condition, subclass|
          condition << "or rec.#{inheritance_column}.to_s == '#{subclass.name.demodulize}' "
        end
      end

      eval "lambda{ |rec| #{type_condition} }"
    end

    # Builds the :conditions block from various forms of input.
    # * Procs are passed as is
    # * Arrays are assumed to be in the format of ['name = ?', 'Assaph']
    # * Fragment String are translated to code
    #   Full SQL statements will raise an error
    # * No parameters will assume a true for all records
    def self.build_conditions_block conditions
      case conditions
        when Proc   then conditions
        when Array  then parse_conditions_from_sql_array(conditions)
        when String
          if conditions.match(/^(SELECT|INSERT|DELETE|UPDATE)/i)
            raise ArgumentError, "KirbyBase does not support SQL for :conditions! '#{conditions.inspect}''"
          else
            conditions_string = translate_sql_to_code(conditions)
            lambda{|rec| eval conditions_string }
          end

        when nil
          if block_given?
            Proc.new
          else
            lambda{|r| true}
          end
      end # case conditions
    end

    # TODO: handle LIKE
    SQL_FRAGMENT_TRANSLATIONS = [
      [/1\s*=\s*1/,            'true'],
      ['rec.',                 ''],
      ['==',                   '='],
      [/(\w+)\s*=\s*/,         'rec.\1 == '],
      [/(\w+)\s*<>\s*?/,       'rec.\1 !='],
      [/(\w+)\s*<\s*?/,        'rec.\1 <'],
      [/(\w+)\s*>\s*?/,        'rec.\1 >'],
      [/(\w+)\s*IS\s+NOT\s*?/, 'rec.\1 !='],
      [/(\w+)\s*IS\s*?/,       'rec.\1 =='],
      [/(\w+)\s+IN\s+/,        'rec.\1.in'],
      [/\.id(\W)/i,            '.recno\1'],
      ['<>',                   '!='],
      [/\bNULL\b/i,            'nil'],
      [/\bAND\b/i,             'and'],
      [/\bOR\b/i,              'or'],
      ["'%s'",                 '?'],
      ['%d',                   '?'],
      [/:\w+/,                 '?'],
      [/\bid\b/i,              'rec.recno'],
    ]
    # Translates SQL fragments to a code string. This code string can then be
    # used to construct a code block for KirbyBase. Relies on the SQL_FRAGMENT_TRANSLATIONS
    # series of transformations. Will also remove table names (e.g. people.name)
    # so not safe to use for joins.
    def self.translate_sql_to_code sql_string
      block_string = SQL_FRAGMENT_TRANSLATIONS.inject(sql_string) {|str, (from, to)| str.gsub(from, to)}
      block_string.gsub(/#{table_name}\./, '')
    end

    # May also be called with a block, e.g.:
    #   Book.count {|rec| rec.author_id == @author.id}
    def self.count(*args)
      if args.compact.empty?
        if block_given?
          find(:all, :conditions => Proc.new).size
        else
          self.find(:all).size
        end
      else
        self.find(:all, :conditions => build_conditions_from_options(args)).size
      end
    end

    # NOT SUPPORTED!!!
    def self.begin_db_transaction
      raise ArgumentError, "#begin_db_transaction called"
      # connection.transaction
    end

    # NOT SUPPORTED!!!
    def self.commit_db_transaction
      raise ArgumentError, "#commit_db_transaction"
      # connection.commit
    end

    # NOT SUPPORTED!!!
    def self.rollback_db_transaction
      raise ArgumentError, "#rollback_db_transaction"
      # connection.rollback
    end

    class << self
      alias_method :__before_ackbar_serialize, :serialize

      # Serializing a column will cause it to change the column type to :YAML
      # in the database.
      def serialize(attr_name, class_name = Object)
        __before_ackbar_serialize(attr_name, class_name)
        connection.change_column(table_name, attr_name, :yaml)
      end
    end
  end

  ##############################################################################
  # INSTANCE METHODS: Override SQL based methods in ActiveRecord::Base
  # Instance methods: everything invoked from records instances,
  # e.g. book = Book.find(:first); book.destroy

  class Base
    # KirbyBase DB Object
    def db
      self.class.db
    end

    # Table for the AR Model class for this record
    def table
      self.class.table
    end

    # DATABASE STATEMENTS ######################################################

    # Updates the associated record with values matching those of the instance attributes.
    def update_without_lock
      table.update{ |rec| rec.recno == id }.set(attributes_to_input_rec)
    end

    # Updates the associated record with values matching those of the instance
    # attributes. Will also check for a lock (See ActiveRecord::Locking.
    def update_with_lock
      if locking_enabled?
        previous_value    = self.lock_version
        self.lock_version = previous_value + 1

        pk = self.class.primary_key == 'id' ? :recno : :id
        affected_rows = table.update(attributes_to_input_rec){|rec| rec.send(pk) == id and rec.lock_version == previous_value}

        unless affected_rows == 1
          raise ActiveRecord::StaleObjectError, "Attempted to update a stale object"
        end
      else
        update_without_lock
      end
    end
    alias_method :update_without_callbacks, :update_with_lock

    # Creates a new record with values matching those of the instance attributes.
    def create_without_callbacks
      input_rec = attributes_to_input_rec
      (input_rec.keys - table.field_names + [:id]).each {|unknown_attribute| input_rec.delete(unknown_attribute)}
      self.id = table.insert(input_rec)
      @new_record = false
    end

    # Deletes the matching row for this object
    def destroy_without_callbacks
      unless new_record?
        table.delete{ |rec| rec.recno ==  id }
      end
      freeze
    end

    # translates the Active-Record instance attributes to a input hash for
    # KirbyBase to be used in #insert or #update
    def attributes_to_input_rec
      field_types = Hash[ *table.field_names.zip(table.field_types).flatten ]
      attributes.inject({}) do |irec, (key, val)|
        irec[key.to_sym] = case field_types[key.to_sym]
          when :Integer
            case val
              when false then 0
              when true then 1
              else val
            end

          when :Boolean
            case val
              when 0 then false
              when 1 then true
              else val
            end

          when :Date
            val.is_a?(Time) ? val.to_date : val

          else val
        end
        irec
      end
    end
  end

  ##############################################################################
  # Associations adaptation to KirbyBase
  #
  # CHANGES FORM ActiveRecord:
  # All blocks passed to :finder_sql and :counter_sql might be called with
  # multiple parameters:
  #   has_one and belongs_to: remote record
  #   has_many: remote record and this record
  #   has_and_belongs_to_many: join-table record and this record
  # Additionally HasAndBelongsToManyAssociation :delete_sql will be called with
  # three parameters: join record, this record and remote record
  # Make sure that all blocks passed adhere to this convention.
  # See ar_base_tests_runner & ar_model_adaptation for examples.
  module Associations
    class HasOneAssociation
      def find_target
        @association_class.find(:first, :conditions => lambda{|rec| rec.send(@association_class_primary_key_name) == @owner.id}, :order => @options[:order], :include => @options[:include])
      end
    end

    class HasManyAssociation
      def find(*args)
        options = Base.send(:extract_options_from_args!, args)

        # If using a custom finder_sql, scan the entire collection.
        if @options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids = args.flatten.compact.uniq

          if ids.size == 1
            id = ids.first
            record = load_target.detect { |record| id == record.id }
            expects_array? ? [record] : record
          else
            load_target.select { |record| ids.include?(record.id) }
          end
        else
          options[:conditions] = if options[:conditions]
            selector = @association_class.build_conditions_from_options(options)
            if @finder_sql
              lambda{|rec| selector[rec] && @finder_sql[rec]}
            else
              selector
            end
          elsif @finder_sql
            @finder_sql
          end


          if options[:order] && @options[:order]
            options[:order] = "#{options[:order]}, #{@options[:order]}"
          elsif @options[:order]
            options[:order] = @options[:order]
          end

          # Pass through args exactly as we received them.
          args << options
          @association_class.find(*args)
        end
      end

      def construct_sql
        if @options[:finder_sql]
          raise ArgumentError, "KirbyBase does not support SQL! #{@options[:finder_sql].inspect}" unless @options[:finder_sql].is_a? Proc
          @finder_sql = lambda{|rec| @options[:finder_sql][rec, @owner] }
        else
          extra_conditions = @options[:conditions] ? @association_class.build_conditions_from_options(@options) : nil
          @finder_sql = if extra_conditions
            lambda{ |rec| rec.send(@association_class_primary_key_name) == @owner.id and extra_conditions[rec] }
          else
            lambda{ |rec| rec.send(@association_class_primary_key_name) == @owner.id }
          end
        end

        if @options[:counter_sql]
          raise ArgumentError, "KirbyBase does not support SQL! #{@options[:counter_sql].inspect}" unless @options[:counter_sql].is_a? Proc
          @counter_sql = lambda{|rec| @options[:counter_sql][rec, @owner] }
        elsif @options[:finder_sql] && @options[:finder_sql].is_a?(Proc)
          @counter_sql = @finder_sql
        else
          extra_conditions = @options[:conditions] ? @association_class.build_conditions_from_options(@options) : nil
          @counter_sql = if @options[:conditions]
            lambda{|rec| rec.send(@association_class_primary_key_name) == @owner.id and extra_conditions[rec]}
          else
            lambda{|rec| rec.send(@association_class_primary_key_name) == @owner.id}
          end
        end
      end

      def delete_records(records)
        case @options[:dependent]
          when true
            records.each { |r| r.destroy }

          # when :delete_all
          #   ids = records.map{|rec| rec.id}
          #   @association_class.table.delete do |rec|
          #     rec.send(@association_class_primary_key_name) == @owner.id && ids.include?(rec.recno)
          #   end

          else
            ids = records.map{|rec| rec.id}
            @association_class.table.update do |rec|
              rec.send(@association_class_primary_key_name) == @owner.id && ids.include?(rec.recno)
            end.set { |rec| rec.send "#@association_class_primary_key_name=", nil}
        end
      end

      def find_target
        @association_class.find(:all,
          :conditions => @finder_sql,
          :order      => @options[:order],
          :limit      => @options[:limit],
          :joins      => @options[:joins],
          :include    => @options[:include],
          :group      => @options[:group]
        )
      end

      # DEPRECATED, but still covered by the AR tests
      def find_all(runtime_conditions = nil, orderings = nil, limit = nil, joins = nil)
        if @options[:finder_sql]
          @association_class.find(@finder_sql)
        else
          selector = if runtime_conditions
            runtime_conditions_block = @association_class.build_conditions_from_options(:conditions => runtime_conditions)
            lambda{|rec| runtime_conditions_block[rec] && @finder_sql[rec] }
          else
            @finder_sql
          end
          orderings ||= @options[:order]
          @association_class.find_all(selector, orderings, limit, joins)
        end
      end

      # Count the number of associated records. All arguments are optional.
      def count(runtime_conditions = nil)
        if @options[:counter_sql]
          @association_class.count(@counter_sql)
        elsif @options[:finder_sql]
          @association_class.count(@finder_sql)
        else
          sql = if runtime_conditions
            runtime_conditions = @association_class.build_conditions_from_options(:conditions => runtime_conditions)
            lambda{|rec| runtime_conditions[rec] && @finder_sql[rec, @owner] }
          else
            @finder_sql
          end
          @association_class.count(sql)
        end
      end

      def count_records
        count = if has_cached_counter?
          @owner.send(:read_attribute, cached_counter_attribute_name)
        else
          @association_class.count(@counter_sql)
        end

        @target = [] and loaded if count == 0

        return count
      end
    end

    class BelongsToAssociation
      def find_target
        return nil if @owner[@association_class_primary_key_name].nil?
        if @options[:conditions]
          @association_class.find(
            @owner[@association_class_primary_key_name],
            :conditions => @options[:conditions],
            :include    => @options[:include]
          )
        else
          @association_class.find(@owner[@association_class_primary_key_name], :include => @options[:include])
        end
      end
    end

    class HasAndBelongsToManyAssociation
      def find_target
        if @custom_finder_sql
          join_records = @owner.connection.db.get_table(@join_table.to_sym).select do |join_record|
            @options[:finder_sql][join_record, @owner]
          end
        else
          join_records = @owner.connection.db.get_table(@join_table.to_sym).select(&@join_sql)
        end
        association_ids = join_records.map { |rec| rec.send @association_foreign_key }

        records = if @finder_sql
                    @association_class.find :all, :conditions => lambda{|rec| association_ids.include?(rec.recno) && @finder_sql[rec]}
                  else
                    @association_class.find :all, :conditions => lambda{|rec| association_ids.include?(rec.recno) }
                  end

        # add association properties
        if @owner.connection.db.get_table(@join_table.to_sym).field_names.size > 3
          join_records = join_records.inject({}){|hsh, rec| hsh[rec.send(@association_foreign_key)] = rec; hsh}
          table = @owner.connection.db.get_table(@join_table.to_sym)
          extras = table.field_names - [:recno, @association_foreign_key.to_sym, @association_class_primary_key_name.to_sym]
          records.each do |rec|
            extras.each do |field|
              rec.send :write_attribute, field.to_s, join_records[rec.id].send(field)
            end
          end
        end

        @options[:uniq] ? uniq(records) : records
      end

      def method_missing(method, *args, &block)
        if @target.respond_to?(method) || (!@association_class.respond_to?(method) && Class.respond_to?(method))
          super
        else
          if method.to_s =~ /^find/
            records = @association_class.send(method, *args, &block)
            (records.is_a?(Array) ? records : [records]) & find_target
          else
            @association_class.send(method, *args, &block)
          end
        end
      end

      def find(*args)
        options = ActiveRecord::Base.send(:extract_options_from_args!, args)

        # If using a custom finder_sql, scan the entire collection.
        if @options[:finder_sql]
          expects_array = args.first.kind_of?(Array)
          ids = args.flatten.compact.uniq

          if ids.size == 1
            id = ids.first.to_i
            record = load_target.detect { |record| id == record.id }
            if expects_array
              [record].compact
            elsif record.nil?
              raise RecordNotFound
            else
              record
            end
          else
            load_target.select { |record| ids.include?(record.id) }
          end
        else
          options[:conditions] = if options[:conditions]
            selector = @association_class.build_conditions_from_options(options)
            @finder_sql ? lambda{|rec| selector[rec] && @finder_sql[rec]} : selector
          elsif @finder_sql
            @finder_sql
          end

          options[:readonly] ||= false
          options[:order] ||= @options[:order]

          join_records = @owner.connection.db.get_table(@join_table.to_sym).select(&@join_sql)
          association_ids = join_records.map { |rec| rec.send @association_foreign_key }
          association_ids &= args if args.all? {|a| Integer === a }
          records = @association_class.find(:all, options).select{|rec| association_ids.include?(rec.id)}
          if args.first.kind_of?(Array)
            records.compact
          elsif records.first.nil?
            raise RecordNotFound
          else
            records.first
          end
        end
      end

      def insert_record(record)
        if record.new_record?
          return false unless record.save
        end

        if @options[:insert_sql]
          raise ArgumentError, "SQL not supported by KirbyBase! #{@options[:insert_sql]}"
          @owner.connection.execute(interpolate_sql(@options[:insert_sql], record))
        else
          columns = @owner.connection.columns(@join_table, "#{@join_table} Columns")

          attributes = columns.inject({}) do |attributes, column|
            case column.name
              when @association_class_primary_key_name
                attributes[column.name] = @owner.id
              when @association_foreign_key
                attributes[column.name] = record.id
              else
                if record.attributes.has_key?(column.name)
                  attributes[column.name] = record[column.name]
                end
            end
            attributes
          end

          input_rec = Hash[*@owner.send(:quoted_column_names, attributes).zip(attributes.values).flatten].symbolize_keys
          @owner.connection.db.get_table(@join_table.to_sym).insert(input_rec)
        end

        return true
      end

      def delete_records(records)
        if sql = @options[:delete_sql]
          delete_conditions = if sql.is_a?(Proc)
            sql
          else
            association_selector = @association_class.build_conditions_from_options(:conditions => sql)
            lambda do |join_rec, owner, record|
              rec.send(@association_foreign_key) == @owner.id &&
              record = @associtation_class.find(rec.send(@association_class_primary_key_name)) &&
              association_selector[record]
            end
          end
          records.each do |record|
            delete_selector = lambda{|join_rec| delete_conditions[join_rec, @owner, record]}
            @owner.connection.db.get_table(@join_table.to_sym).delete(&delete_selector)
          end
        else
          ids = records.map { |rec| rec.id }
          @owner.connection.db.get_table(@join_table.to_sym).delete do |rec|
            rec.send(@association_class_primary_key_name) == @owner.id && ids.include?(rec.send(@association_foreign_key))
          end
        end
      end

      def construct_sql
        if @options[:finder_sql]
          @custom_finder_sql = lambda{|rec| @options[:finder_sql][rec, @owner, @association_class.find(rec.send(@association_class_primary_key_name))] }
        else
          # Need to run @join_sql as well - see #find above
          @finder_sql = @association_class.build_conditions_from_options(@options)
        end

        # this should be run on the join_table
        # "LEFT JOIN #{@join_table} ON #{@association_class.table_name}.#{@association_class.primary_key} = #{@join_table}.#{@association_foreign_key}"
        @join_sql = lambda{|rec| rec.send(@association_class_primary_key_name) == @owner.id}
      end

    end
  end

  ##############################################################################
  # A few methods using raw SQL need to be adapted
  class Migrator
    def self.current_version
      Base.connection.get_table(schema_info_table_name.to_sym).select[0].version.to_i rescue 0
    end

    def set_schema_version(version)
      Base.connection.get_table(self.class.schema_info_table_name.to_sym).update_all(:version => (down? ? version.to_i - 1 : version.to_i))
    end
  end

  ##############################################################################
  ### WARNING: The following two changes should go in the ar_test_runner as well!!

  # Needed to override #define as it was using SQL to update the schema version
  # information.
  class Schema
    def self.define(info={}, &block)
      instance_eval(&block)

      unless info.empty?
        initialize_schema_information
        ActiveRecord::Base.connection.get_table(ActiveRecord::Migrator.schema_info_table_name.to_sym).update_all(info)
      end
    end
  end

  # Override SQL to retrieve the schema info version number.
  class SchemaDumper
    def initialize(connection)
      @connection = connection
      @types = @connection.native_database_types
      @info = @connection.get_table(:schema_info).select[0] rescue nil
    end
  end

  ### WARNING: The above two changes should go in the ar_test_runner as well!!
  ##############################################################################
end

###############################################################################
# Fixtures adaptation to KirbyRecord
require 'active_record/fixtures'

# Override raw SQL for ActiveRecord insert/delete Fixtures
class Fixtures
  # Override raw SQL
  def delete_existing_fixtures
    begin
      tbl = @connection.db.get_table(@table_name.to_sym)
      tbl.clear
      @connection.db.engine.reset_recno_ctr(tbl)
    rescue => detail
      STDERR.puts detail, @table_name
    end
  end

  # Override raw SQL
  def insert_fixtures
    tbl = @connection.db.get_table(@table_name.to_sym)
    column_types = Hash[*tbl.field_names.zip(tbl.field_types).flatten]
    items = begin
      values.sort_by { |fix| fix['id'] }
    rescue
      values
    end
    items.each do |fixture|
      insert_data = fixture.to_hash.symbolize_keys.inject({}) do |data, (col, val)|
        data[col] =  case column_types[col]
          when :String   then val.to_s
          when :Integer  then val.to_i rescue (val ? 1 : 0)
          when :Float    then val.to_f
          when :Time     then Time.parse val.to_s
          when :Date     then Date.parse val.to_s
          when :DateTime then DateTime.parse(val.asctime)
          else val # ignore Memo, Blob and YAML for the moment
        end
        data
      end
      insert_data.delete(:id)
      recno = tbl.insert(insert_data)
      fixture.recno = recno
    end
  end
end

# Override raw finder SQL for ActiveRecord Fixtures
class Fixture
  attr_accessor :recno
  def find
    if Object.const_defined?(@class_name)
      klass = Object.const_get(@class_name)
      klass.find(:first) { |rec| rec.recno == recno }
    end
  end
end

################################################################################
# Stdlib extensions
class Array
  # Modifies the receiver - sorts in place by the given attribute / block
  def sort_by!(*args, &bl)
    self.replace self.sort_by(*args, &bl)
  end

  # Will now accept a symbol or a block. Block behaves as before, symbol will
  # be used as the property on which value to sort elements
  def sort_by(*args, &bl)
    if not bl.nil?
      super &bl
    else
      super &lambda{ |item| item.send(args.first) }
    end
  end

  # A stable sort - preserves the order in which elements were encountred. Used
  # in multi-field sorts, where the second sort should preserve the order form the
  # first sort.
  def stable_sort
    n = 0
    sort_by {|x| n+= 1; [x, n]}
  end

  # Stable sort by a particular attribute.
  def stable_sort_by(*args, &bl)
    n = 0
    if not bl.nil?
      super &bl
      sort_by { |item| n+=1; [bl[item], n] }
    else
      sort_by { |item| n+=1; [item.send(args.first), n] }
    end
  end
end

# Stdlib extensions
class Object
  # The inverse to ary.include?(self)
  def in *ary
    if ary.size == 1 and ary[0].is_a?(Array)
      ary[0].include?(self)
    else
      ary.include?(self)
    end
  end
end

