require "bundler/setup"
require "active_support"
require "sqlite3"
require 'bigdecimal'

default_csv_file = "coinbase.csv"

puts "Welcome"
puts "Please enter the path to a full transaction report CSV file from coinbase"
puts "You can drag and drop the file in your terminal here"
puts "Remove the leading nonsense text before the header row before continuing."
puts "Default: coinbase.csv"

csv_file = gets.chomp.presence
csv_file ||= default_csv_file

puts "Calculated balances for #{csv_file}"

# `cat << EOF | ` closes the interactive sqlite3 process
system(%Q{rm transactions.db && cat << EOF | sqlite3 -cmd ".import --csv #{csv_file} transactions" transactions.db})

db = SQLite3::Database.new "transactions.db"

class Tx
  def initialize(data)
    @data = data
  end

  def type
    @data[1]
  end

  def coin
    @data[2]
  end

  def amount
    BigDecimal(@data[3])
  end

  def conversion
    _ign1, source_amount, source_coin, _ign2, destination_amount, destination_coin = @data[9].split(" ")
    [
      ConversionTx.new("Sell", source_coin, source_amount),
      ConversionTx.new("Buy", destination_coin, destination_amount),
    ]
  end
end

class ConversionTx
  attr_reader :type, :coin, :amount
  def initialize(type, coin, amount)
    @type = type
    @coin = coin
    @amount = BigDecimal(amount.gsub(",", ""))
  end
end

class Ledgers
  def initialize
    @ledgers = {}
  end

  def fetch(coin)
    ledger = @ledgers.fetch(coin, Ledger.new(coin, 0))
    @ledgers[coin] = ledger
  end

  def summarize
    @ledgers.values.map do |ledger|
      ledger.report
    end.join("\n")
  end
end

class Ledger
  attr_reader :coin, :value

  def initialize(coin, value)
    @coin = coin
    @value = BigDecimal(value)
  end

  def buy(tx)
    @value += tx.amount
  end

  def paid_for_an_order(tx)
    @value -= tx.amount
  end

  def receive(tx)
    @value += tx.amount
  end

  def sending(tx)
    @value -= tx.amount
  end

  def sell(tx)
    @value -= tx.amount
  end

  def convert(tx, ledgers)
    source, destination = tx.conversion

    ledgers.fetch(source.coin).sell(source)
    ledgers.fetch(destination.coin).buy(destination)
  end

  def report
    "#{coin}: #{"%.2f" % value}"
  end
end

ledgers = Ledgers.new

db.execute("select * from transactions").each do |row|
  tx = Tx.new(row)
  ledger = ledgers.fetch(tx.coin)

  case tx.type
  when "Buy" then ledger.buy(tx)
  when "Paid for an order" then ledger.paid_for_an_order(tx)
  when "Receive" then ledger.receive(tx)
  when "Send" then ledger.sending(tx)
  when "Sell" then ledger.sell(tx)
  when "Convert" then ledger.convert(tx, ledgers)
  else
    raise "Unknown transaction type #{tx.type}"
  end
end

puts ledgers.summarize
