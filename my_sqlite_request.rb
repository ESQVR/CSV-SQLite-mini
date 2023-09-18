# frozen_string_literal: true

require 'csv'

class FileNotFound < StandardError; end
class InvalidOperator < StandardError; end

# Database Class: Creates an instance that loads data from external CSV files.
# Responds to SQLite style queries sent from a separate CLI script: my_sqlite_cli.rb
# Methods in Database Class maintain data in CSV::Table/Row objects wherever possible.
# Includes methods to modify and write to external CSV files.
class Database
  def initialize
    @method_chain = []
  end

  # CLI processes args_hash and sends Key as method_name and Values as *args
  # Appends array [method, *args] to @method_chain for run to execute
  def add_method(method_name, *args)
    @method_chain << [method_name.downcase.to_sym, *args]
  end

  # Sets various logic checks to ensure printing/ordering occur according to query options
  def bool_options
    @join_true = @method_chain.any? { |subarray| subarray.include?(:join) }
    @order_true = @method_chain.any? { |subarray| subarray.include?(:order) }
    @where_true = @method_chain.any? { |subarray| subarray.include?(:where) }
    @order_early = false
  end

  # Runs all methods (2 element arrays) found in @method_chain with their arguments
  # First sorts arrays according to order_mapping list
  # Second extracts method names and *args from each sub-array
  # Third uses send to execute each method with its arguments
  def run
    bool_options
    order_mapping = { from: 1, update: 2, where: 3, and: 4, or: 5,
                      selected: 6, insert: 7, deletes: 8, set: 9,
                      join: 10, on: 11, order: 12 }
    @method_chain.sort_by! { |element| order_mapping[element[0]] }
    @method_chain.each do |method_info|
      method_name, *args = method_info
      send(method_name, *args)
    end
  end

  # Creates CSV::Table object containing parsed CSV data from external file (identified in argument)
  def from(file_name)
    @current_file_name = file_name
    begin
      @csv_table_from_file = CSV.read(file_name, headers: true)
    rescue Errno::ENOENT
      raise FileNotFound, "Error: Cannot find csv file: #{file_name}" unless @csv_table_from_file
    end
    self
  end

  # WHERE operators are assigned lambdas in a hash to be called from WHERE/AND/OR
  def operator_mapping
    {
      '=' => ->(row, value) { row == value },
      '!=' => ->(row, value) { row != value },
      '>' => ->(row, value) { row.to_i > value.to_i },
      '<' => ->(row, value) { row.to_i < value.to_i }
    }
  end

  # Creates subset of rows according to query options
  def where(col_name, operator, value)
    @where_array_csv_rows = @csv_table_from_file.select do |row|
      operator_mapping[operator].call(row[col_name], value)
    end
    self
  end

  # Excludes non-matching rows from WHERE list
  def and(col_name, operator, value)
    @where_array_csv_rows.select! do |row|
      operator_mapping[operator].call(row[col_name], value)
    end
    self
  end

  # Includes matching rows in WHERE list
  def or(col_name, operator, value)
    or_rows = @csv_table_from_file.select do |row|
      operator_mapping[operator].call(row[col_name], value)
    end
    @where_array_csv_rows += or_rows
    self
  end

  # Handles ORDERing on columns not selected
  def order_early(*columns)
    headers = columns == ['*'] ? @csv_table_from_file&.headers : Array(columns)
    # Extracts order for early ordering (Ordering on non-selected column)
    order_args = @method_chain.select { |subarray| subarray.include?(:order) }
    order_args = order_args.flatten
    order_args.shift

    return unless @order_true && !headers.include?(order_args[0])

    @order_early = true
    @order_true = false
    array_of_csv_rows = @where_true ? @where_array_csv_rows : @csv_table_from_file.select { true }
    order_hidden(array_of_csv_rows, order_args[0], order_args[1])
  end

  # Build new table with only specified columns, Calls for early ordering if ORDER on non-select column
  def selected(*columns)
    headers = columns == ['*'] ? @csv_table_from_file&.headers : Array(columns)
    order_early(headers, *columns) if @method_chain.any? { |subarray| subarray.include?(:order) }

    @selected_items_table = CSV::Table.new([], headers: headers)

    table = @where_true ? @where_array_csv_rows : @csv_table_from_file
    table&.each do |row|
      @selected_items_table << CSV::Row.new(headers, headers.map { |col| row[col] })
    end

    @selected_items_array = []
    @selected_items_array = @selected_items_table.select { true }
    format_and_print(@selected_items_table) unless @join_true || @order_true
    self
  end

  # Opens the second table for JOIN, assigning all headers, or selected columns
  def join(file_name2)
    @join_table = CSV::Table.new(CSV.read(file_name2, headers: true))
    headers = if @method_chain.any? { |subarray| subarray[0] == :selected && subarray.include?('*') }
                @selected_items_table.headers + @join_table.headers
              else
                @selected_items_table.headers
              end
    @combined_table = CSV::Table.new([], headers: headers)
  end

  # Fills combined table from join with values from specified rows
  def on(column_name_a, _operator, column_name_b)
    @selected_items_table.each do |join_row|
      matching_rows = @join_table.select { |row| row[column_name_b] == join_row[column_name_a] }
      matching_rows.each do |selected_row|
        combined_row = CSV::Row.new(@combined_table.headers, [])
        @combined_table.headers.each do |header|
          combined_row[header] = selected_row[header] || join_row[header]
        end
        @combined_table << combined_row
      end
    end
    @order_true ? @combined_array = @combined_table.select { true } : format_and_print(@combined_table)
  end

  # Sorts @where_array on column name received as argument. Ascending is default, descending if argument.
  def order(column, order)
    return if @order_early

    sort_table = @join_true ? @combined_array : @selected_items_array
    @ordered_array_csv_rows = sort_table.sort_by! { |row| [row[column].nil? ? 0 : 1, row[column]] }
    @ordered_array_csv_rows = sort_table.reverse! if order.downcase == 'desc'
    format_and_print(@ordered_array_csv_rows)
    self
  end

  # In case ordering is needed before final step (ORDERing on non-SELECTed column)
  def order_hidden(array_of_csv_rows, column, order)
    @print_early_sorting = array_of_csv_rows.sort_by! { |row| [row[column].nil? ? 0 : 1, row[column]] }
    @print_early_sorting = array_of_csv_rows.reverse! if order.downcase == 'desc'
    @csv_table_from_file = @print_early_sorting
  end

  # Opens target CSV file and appends values from argument as new row
  # Fills Left to right if no columns given, matches columns if provided
  def insert(file_name, data_hash)
    CSV.open(file_name, 'a') do |csv|
      if data_hash.keys.first == 'NO_COLUMNS'
        data_hash.each_value { |value| csv << value }
      else
        headers = CSV.read(file_name, headers: true).headers
        row = headers.map { |col| data_hash[col] || nil }
        csv << row
      end
    end
  end

  # Creates new CSV::Table from file, fills seconds ::Table with all rows EXCEPT those selected by WHERE
  # Opens target file in "a" (append) mode, writes contents of second (EXCEPT) table
  def deletes
    result_table = if @where_array_csv_rows.nil?
                     CSV::Row.new([], [])
                   else
                     @csv_table_from_file&.reject { |row| @where_array_csv_rows.include?(row) }
                   end
    overwrite_file(result_table)
  end

  # Calls from and creates an alias of resulting @csv_table_from_file: @update_table
  def update(file_name)
    from(file_name.to_s)
    @update_table = @csv_table_from_file
    self
  end

  # Receives [data_hash] from SET command ("column"=>"value", ...)
  # If user gives a WHERE command, updates only specific rows, otherwise updates ALL rows in ::Table
  def set(data_hash)
    rows_to_update = @where_array_csv_rows.nil? ? @update_table : @where_array_csv_rows
    rows_to_update.each do |row|
      data_hash.each { |key, value| row[key] = value if row.headers.include?(key) }
    end
    overwrite_file(@update_table)
    self
  end

  # Takes CSV::Table from :deletes and :update
  # Overwrites all values with ::Table
  def overwrite_file(data_table_to_write)
    CSV.open(@current_file_name, 'wb') do |csv|
      csv << @csv_table_from_file.headers
      data_table_to_write.each { |row| csv << row }
    end
  end

  # Prints CSV::Table to output formatted in SQLite-style
  def format_and_print(final_output)
    final_output.each do |row|
      formatted_row = row.fields.join('|')
      puts formatted_row
    end
    self
  end
end
