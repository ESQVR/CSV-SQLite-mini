# CSV-SQLite-mini
A ruby implementation of a basic SQLite3-style database management system for CSV files. Lets you use some simple SQLite3 commands on CSV files.

# Welcome to My Sqlite
***

## Task
The My Sqlite project provides a command-line interface (CLI) tool for working with CSV files, enabling users to perform SQL-like operations on their data. 
This tool consists of two main components: my_sqlite_cli.rb (the CLI interface) and my_sqlite_request.rb (the underlying data processing logic). 

## Description
My SQlite is a Ruby implementation of a basic SQLite3 command line database tool for use with CSV files, allowing SQLite-style operations to be performed on CSV files as if they were tables.
The Ruby CSV library is used to handle database style operations; file parsing, data management, and I/O operations.

The gem Thor is used for handling CLI operations like input parsing, some error handling, help manual functions, as well as using the my_sqlite_request file’s database class objects.

The database file is written as a fluent interface API/DSL where all commands are collected in an object from the CLI, and executed in a chain. 
his allows the program to be easily extended with additional methods and features simply added to the method chain when called by the CLI. 

## Installation
My Sqlite was built to run on Ruby 3.2.2 has been tested and verified to work with version 3.1.2 you may experience issues running it on earlier versions.

My Sqlite depends on bundler to install needed gems, to install bundler:

```gem install bundler```

The Command-Line-Interface (CLI) requires the Thor gem which is included in the vendor/bundle directory and should install itself when program is launched

To install and set up the My Sqlite tool, follow these steps:

Download or clone the repository to your local machine.
Open a terminal and navigate to the project directory.
Run the CLI interface using the following command:

```ruby my_sqlite_cli.rb```

If you encounter issues use bundler execution instead:

```bundle exec ruby your_program.rb```


## Usage
The My Sqlite CLI tool enables you to perform various operations on CSV files using SQL-like keywords. Here's how to use it:

When the CLI launches you will see this prompt:

CSV-QLite version 1.0.0
my_sqlite_cli >

Listing commands / getting help:
To see a full list of available commands, you can use “help” to retrieve commands and example usage for each. 
You may also enter “help [command]” to view instructions for a particular command.

```my_sqlite_cli > help```

To quit the CLI use “quit”

```my_sqlite_cli > quit```

About My Sqlite command keywords generally:
Keywords in My Sqlite are case sensitive - commands should be placed in all CAPS
CLI inputs are space-separated, so when entering values that have multiple words, you must enclose them in single ‘’ or double “” quotes

*******

#### SELECT:

The SELECT keyword lets users query the data in a CSV file and displays the results. 

You can specify the columns to retrieve or use the * operator for all columns in the table.
Rows/records can be filtered based on their content using with WHERE
- WHERE [Column] [=,!=,>,<] [Field Value]
Complex filtering is possible by adding additional optional keywords AND, or OR
- WHERE … AND [Column] [=,!=,>,<] [Field Value] (results must match both)
- WHERE … OR [Column] [=,!=,>,<] [Field Value] (results can match either)
Results can be ordered using ORDER and ASC/DESC for ascending / descending
- … ORDER [Column] [ASC/DESC]

A full SELECT command can look like:
- SELECT * FROM [File_path]
- SELECT [Column, ...] FROM [File_path] WHERE/AND/OR [Column] [=,!=,>,<] [value] ORDER [Column] [Order]

#### INSERT INTO:

The INSERT INTO keyword will append a new row at the end of a specified CSV file. It will accept two different syntaxes, specifying columns, or filling row Left->Right.

For entering values in specific columns use:

- INSERT INTO [File_path] ( [Column_1] [...]) VALUES ["Value 1"] ["..."]

For filling the columns in the new row left to right use:

- INSERT INTO [File_path] VALUES ["Value 1"] ["..."]

#### UPDATE:

The UPDATE keyword will modify specific rows in the CSV file. Rows are specified with WHERE/AND/OR optional keywords. 

***Caution - If no WHERE command is used, all rows in the file will be updated.***

UPDATE is used with SET to specify what columns to modify, and WHERE to select rows:
- UPDATE [Filename] SET [column = "value"], [...] WHERE [Column] [=,!=,>,<] [value] 
To UPDATE all rows, exclude the WHERE option:
- UPDATE [Filename] SET [column = "value"], [...] WHERE [Column] [=,!=,>,<] [value] 

#### DELETE:

The DELETE keyword is used to remove rows/records from a CSV file. DELETE is combined with WHERE/AND/OR optional keywords to specify which rows to delete. 
If WHERE is not included in the command, all rows (including headers) will be deleted.

***DELETE operations cannot be undone and should be used with caution.***

- DELETE FROM [File_name] WHERE [Column_name] [=,!=,>,<] [value]

## TEST COMMANDS
Here are some test commands that may be used to demonstrate the functionality of My Sqlite using the included csv demo files

INSERT INTO nba_players.csv (Player, height, weight, born, birth_state) VALUES ('Victor Wembanyama', '224', '95', '2004', 'France')

SELECT Player, born, birth_state FROM nba_players.csv WHERE born > 1995 ORDER born ASC

DELETE FROM nba_players.csv WHERE Player = "Victor Wembanyama"

SELECT Player, birth_date, born, collage, height FROM nba_players.csv JOIN nba_player_data.csv ON Player = name

SELECT * FROM nba_players.csv WHERE born > 1996

INSERT INTO nba_players.csv (Player, height, weight, born, birth_state) VALUES ('Victor Wembanyama', '224', '95', '2004', 'France')

SELECT * FROM nba_players.csv WHERE born > 1996

UPDATE nba_players.csv SET Player = "Test Player", born = 2004, birth_state = "New Mexico" WHERE Player = "Victor Wembanyama"

SELECT * FROM nba_players.csv WHERE born > 1996

DELETE FROM nba_players.csv WHERE Player = "Test Player"

SELECT * FROM nba_players.csv WHERE born > 1996

SELECT * FROM nba_players.csv JOIN nba_player_data.csv ON Player = name ORDER college ASC

SELECT Player, position, birth_state FROM nba_players.csv JOIN nba_player_data.csv ON Player = name ORDER born DESC

SELECT Player, born FROM nba_players.csv ORDER born DESC

SELECT height, Player, born FROM nba_players.csv ORDER height DESC

UPDATE nba_players.csv SET birth_city = "San Francisco", birth_state = CA WHERE Player = "Test Player"


### The Core Team
Septime Champenois

Christopher Deetz

<span><i>Made at <a href='https://qwasar.io'>Qwasar SV -- Software Engineering School</a></i></span>
<span><img alt='Qwasar SV -- Software Engineering School's Logo' src='https://storage.googleapis.com/qwasar-public/qwasar-logo_50x50.png' width='20px'></span>
