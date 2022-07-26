# What is this

A script to calculate the account balances for each coin given a full transaction report which you can download
from Coinbase.

```
WIP: the account balances currently don't match the numbers from Coinbase. Either the transaction report is incomplete or there are still bugs in the script.
```

## Running the script

Needs `ruby` and `bundler` (`gem install bundler`).

Then run `bundle`

Download a full transaction report from Coinbase and place it alongside `main.rb`
Remove all the crap before the header row.

Then run `ruby main.rb` to see the balances.
