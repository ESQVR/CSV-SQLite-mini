#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
Bundler.require

require 'readline'
require 'thor'
require_relative 'my_sqlite_request'

class MySQLite < Thor
  puts 'CSV-QLite version 1.0.0' # Welcome Message

  # Prevents program from quitting when a bad command is given
  def self.exit_on_failure?
    false
  end

  # The following methods are available to CLI when interface calls MySQLite.start([command, *args])
  # Thor uses 'command' argument to select method to call, and sends '*args' to that method

  # quit will exit CLI
  desc 'quit', 'This command will exit the program with code 0'
  def quit
    exit 0
  end

  # The primary CLI commands are SQLite KEYWORDS (SELECT, INSERT, UPDATE, DELETE)
  # The first input KEYWORD, removed by Thor interface, is replaced when sending input to sqlite_command_parser
  # SELECT and DELETE are renamed during replacement to avoid conflicts with built-in methods

  # SELECT is used to query CSV file and display results
  desc 'SELECT', 'SELECT [Column, ...] or [*] FROM [File_path] WHERE/AND/OR [Column] [=,!=,>,<] [value]'
  def SELECT(*args)
    args_hash = sqlite_command_parser('SELECTED', *args)
    execute_database_commands(args_hash)
  end

  # INSERT is used to append a row of values to a specified CSV file.
  desc 'INSERT INTO', 'INSERT INTO [File_name] ( [Column_1] [...]) VALUES ["Value 1"] ["..."]'
  def INSERT(*args)
    args_hash = sqlite_command_parser('INTO', *args)
    args_hash = insert_parser(args_hash)
    execute_database_commands(args_hash)
  end

  # DELETE is used to remove rows specified with WHERE/AND/OR from specified CSV file
  desc 'DELETE', 'DELETE FROM [File_name] WHERE [Column_name] [=,!=,>,<] ["Row(s) to match"]'
  def DELETE(*args)
    args_hash = sqlite_command_parser('DELETES', *args)
    args_hash['DELETES'] = []
    execute_database_commands(args_hash)
  end

  # UPDATE modifies specified columns in an existing row of a CSV file
  # Columns and values specified in SET are parsed and converted to hash of column=>value
  desc 'UPDATE', 'UPDATE [Filename] SET [column = "value"], [...]'
  def UPDATE(*args)
    args_hash = sqlite_command_parser('UPDATE', *args)
    args_hash = update_set_parser(args_hash)
    execute_database_commands(args_hash)
  end

  # Utility Methods, hidden from Command Line users
  no_commands do

    # Parses user input into args_hash
    #   Strings appearing in keyword_list create new keys strings following any KEYWORD fill a values array in that key
    #   args_hash is used by Database instance to execute fluent interface commands
    def sqlite_command_parser(command, *args)
      keyword_list = %w[SELECTED INTO UPDATE DELETES FROM SET WHERE AND OR VALUES ORDER JOIN ON]
      args_hash = {}
      current_keyword = command
      args.each do |string|
        if keyword_list.include?(string)
          current_keyword = string
        else
          cleaned_arg = string.delete(',()\'"').gsub('+', ' ')
          args_hash[current_keyword] ||= []
          args_hash[current_keyword] << cleaned_arg
        end
      end
      %w[OR AND].each { |key| args_hash = multiplier_hash(args_hash, key) if args_hash.key?(key) }
      args_hash
    end

    # Parses INSERT and INTO keys, INSERTING in either specified columns or Left->Right (no columns given)
    def insert_parser(args_hash)
      args_hash['INSERT'] = [args_hash['INTO'].shift]

      # When INTO key is empty (no columns specified) NO_COLUMNS hash with array of VALUES is appended to INSERT key
      if args_hash['INTO'].empty?
        args_hash['INSERT'] << { 'NO_COLUMNS' => args_hash['VALUES'] }
        args_hash.delete('INTO')
        args_hash.delete('VALUES')
        return args_hash
      end

      # When INTO key contains column names values_hash (column=>values) is appended to INSERT key
      values_hash = args_hash.values_at('INTO').flatten.zip(args_hash.values_at('VALUES').flatten).to_h
      args_hash['INSERT'] << values_hash
      args_hash.delete('INTO')
      args_hash.delete('VALUES')
      args_hash
    end

    # Parses SET key into hash of 3-value-arrays
    def update_set_parser(args_hash)
      set_args = args_hash['SET'].each_slice(3).to_a
      set_hash = {}
      set_args.map do |sub_arrays|
        key, _, value = sub_arrays
        set_hash[key] = value
      end
      args_hash['SET'] = [set_hash]
      args_hash
    end

    # Multiple AND/OR clauses must be stored as sub-arrays in their keys
    def multiplier_hash(args_hash, and_or)
      and_or_array = args_hash[and_or].each_slice(3).to_a
      args_hash[and_or] = []
      and_or_array.each { |sub| args_hash[and_or] << sub }
      args_hash
    end

    # Calls add_method in Database instance to create method chain
    #   Multiple AND/OR clauses stored in sub-arrays are added as separate method calls
    def build_method_chain(args_hash)
      args_hash.each do |key, value|
        case key
        when 'OR', 'AND'
          value.each { |subarray| @data.add_method(key, *subarray) }
        else
          @data.add_method(key, *value)
        end
      end
    end

    # Instantiates new Database object (from my_sqlite_request.rb)
    #   Adds methods/args to @method_chain[] and executes chain with .run method
    def execute_database_commands(args_hash)
      @data = Database.new
      build_method_chain(args_hash)

      # ERROR HANDLING
      begin
        @data.run
      rescue FileNotFound => e
        puts e.message
      rescue InvalidOperator => e
        puts e.message
      rescue StandardError => e
        puts "INVALID COMMAND SYNTAX ---- Calling for help!"
        help
      end
    end
    # END of no_commands (private utility methods) block
  end
end

# Main program loop for CLI. Takes user input and sends to MyCLI(Thor) Class.
def interface
  # Readline creates prompt, and awaits input. True lets arrow keys access input history.
  while (input = Readline.readline('my_sqlite_cli > ', true))

    # REGEX: Search for multi-word inputs enclosed in "" or '' spaces are replaced with "+"
    clean_input = input.gsub(/['"]([^'"]*)['"]/) { |match| match.gsub(' ', '+') }
    args = clean_input.split(' ')
    command = args.shift

    # Thor uses the first element in the args array of input strings to specify which CLI method to execute
    MySQLite.start([command, *args])
  end
end

interface # Launch interface
