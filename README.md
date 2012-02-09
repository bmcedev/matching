# matching

Matching is a library for performing rules-based matches between records in two
datasets. These datasets are typically from two different sources that pertain
to the same or similar set of transactions. Matching allows you to compare
the datasets and produces an array of matched records as well as an array of
exceptions (nonmatches) for each input dataset.

Matching is designed primarily for reconciliations. Example use cases:

* Bank reconciliations, where input datasets come from an accounting system and an
  online bank statement.

* Cellular commission reconciliation, where input datasets come from an
  independent retailer's Point Of Sale system and a carrier's commission
statement.

This library is not a replacement for database joins on a
properly-designed RDBMS. It's designed for real-world situations where
the programmer must handle data from different sources that are nonetheless
similar. 

## Example

To illustrate how Matching is useful in situations where a database join can
lead to errors, take the example of reconciling a bank statement against an
accounting system's transactions. In this example, the bookeeper incorrectly
recorded a transaction twice and the two Github transactions have different dates.

#### Accounting System

<table>
  <tr><th>Date</th><th>Description</th><th>Amount</th><tr>
  <tr>
    <td>2012-01-01</td>
    <td>Basecamp</td>
    <td>25.00</td>
  </tr>
  <tr>
    <td>2012-01-01</td>
    <td>Basecamp</td>
    <td>25.00</td>
  </tr>
  <tr>
    <td>2012-01-02</td>
    <td>Github</td>
    <td>25.00</td>
  </tr>
</table>

#### Bank Statement

<table>
  <tr><th>Date</th><th>Description</th><th>Amount</th><tr>
  <tr>
    <td>2012-01-01</td>
    <td>Basecamp (37 signals)</td>
    <td>25.00</td>
  </tr>
  <tr>
    <td>2012-01-03</td>
    <td>Github</td>
    <td>25.00</td>
  </tr>
</table>

Using a database approach, you might load the datasets into two tables,
"ledger" and "bank" then join on amount:

``` sql
  select * from ledger a join bank b on a.amount = b.amount;

  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-01|Basecamp|25.0|2012-01-03|Github|25.0  
  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-01|Basecamp|25.0|2012-01-03|Github|25.0  
  2012-01-02|Github|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-02|Github|25.0|2012-01-03|Github|25.0  
```

That's clearly not the right answer. Because amount was the only criterion
used for joining, the query joins each record with a $25 value (3*2 pairs).

OK, how about adding in the date:

``` sql
  select * from ledger a join bank b on a.amount = b.amount and a.date = b.date;

  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
```

Still incorrect because the bookeeper recorded the Github transaction on Jan. 2
and the bank shows the debit on Jan. 3. How about using description and amount?

``` sql
  select * from ledger a join bank b on a.amount = b.amount and a.description = b.description;

  2012-01-02|Github|25.0|2012-01-03|Github|25.0
```

Even worse. Because two different people or systems entered these records, they
have slightly different descriptions. Now you might try some more complidated SQL:

``` sql
  select * from ledger a join bank b on a.amount = b.amount and (a.description = b.description or a.date = b.date);

  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-02|Github|25.0|2012-01-03|Github|25.0  
``` 

At first blush that might look right, but because there are two bank statement
lines, a correctly matched result *must not* contain more than two
records. What we want is this:

``` sql
  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0    
  2012-01-02|Github|25.0|2012-01-03|Github|25.0  
```

### Solution using Matching

``` ruby
require 'matching'
include Matching

class Transaction
  attr_accessor :date, :desc, :amount
  def initialize(date, desc, amount)
    @date, @desc, @amount = date, desc, amount     
  end
  def to_s
    [@date, @desc, @amount].join(',') 
  end
end

ledger_txns = [
  Transaction.new(Date.new(2012,1,1),'Basecamp','25.0'),
  Transaction.new(Date.new(2012,1,1),'Basecamp','25.0'),
  Transaction.new(Date.new(2012,1,2),'Github','25.0')
]

bank_txns = [
  Transaction.new(Date.new(2012,1,1),'Basecamp (37 signals)','25.0'),
  Transaction.new(Date.new(2012,1,3),'Github','25.0')
]

matcher = Matcher.new(
  :left_store => ArrayStore.new(ledger_txns),
  :right_store => ArrayStore.new(bank_txns),
  :min_score => 1.0
)

matcher.define do
  join    :amount,  :amount,  1.0
  compare :date,    :date,    0.5,  :fuzzy => true
end

matcher.match

puts "Matches:\n"
matcher.matches.each do |match|
  puts [match.left_obj, "%.2f" % match.score, match.right_obj].join(',')
end

puts "Left exceptions:\n"
matcher.left_exceptions.each { |l_exc| puts l_exc }

puts "Right exceptions:\n"
matcher.right_exceptions.each { |r_exc| puts r_exc }

```

This is the correct result according to the rules we supplied to the matcher. 

``` bash
Matches:
2012-01-01,Basecamp,25.0,1.50,2012-01-01,Basecamp (37 signals),25.0
2012-01-02,Github,25.0,1.48,2012-01-03,Github,25.0
Left exceptions:
2012-01-01,Basecamp,25.0
Right exceptions:
```

## How It Works

Data is loaded into the matcher using either an ArrayStore or an ActiveRelationStore. These classes use duck typing and it
would be simple to create your own for different data sources.

You describe the matching rules during initialization and a "define" block. Initialize expects a "left" and "right" data store
and optionally a minimum score for considering two objects to be a match (default is 1.0). The matcher assigns a float score to each matched object pair
according to the rules you supply. 

The define block describes which attribute pairs from the left and right data stores will be used for comparison, how they are
to be compared, and the score assigned for a successful pairing. In the example above, all objects are from the same class (Transaction)
but this isn't required. 

Attribute pairs are either joined or compared. Joined attributes are indexed in either a hash (default) or Redis and the matcher
does a lookup for each left object and first gets an array of potential right matches via a union of searches against the indexes
by join attributes. It then applies comparison rules to create a total score of the match between the left object and all
candidate matches on the right. 

In cases where a match is "contested" because the highest-scored right candidate is already matched, the left object with the highest
score is awarded the match and the "loser" has a chance to match to its next-highest ranked right object, if any exists. In situations
where there is no right object with a high enough score to pair, that left object is added to the array of left exceptions. Right exceptions
are created from the array of right objects that fail to pair with any left object.

## Describing match pairs

At least one join (exact match) pair must be defined. My company uses this system for analyzing data with serialized values. In our experience, record pairs with no exact matches are typically low-quality matches and are
best left for a manual review process. Also, without the benefit of indexing, comparing every left object against every right
object would kill performance for large datasets. 

``` ruby
# Join "amount" from both the left and right data stores and award a 1.0 to each pairing
matcher.define do
  join  :amount,  :amount,  1.0
end
```

If multiple joins are defined, that means one index for each join pair will be created. It *does not* mean that both joins
must be satisfied in order for a pair to be awarded a score. Scores are additive and the highest-scored pair "wins".

``` ruby
# Join on first and last names, giving higher weight to the last name
# This is analogous to a database OR join (not AND). Later scoring will link only
# the highest-scoring pair.
matcher.define do
  join  :first,   :first_name,  0.5
  join  :last,    :last_name,   1.0
end
```

Comparisons are performed after joins have created a filtered array of right objects for each left object. The result of
each comparison is added to the score awarded by joins. 

``` ruby
# Award an additional point for each pair where the age attribute is the same. Attributes with frequent value 
# commonality are poor candiates for joins because many comparisons will be made between left and right object pairs. 
# It's best to use attributes with frequent unique values for joins (e.g. name, phone number, SSN, etc.) 
# and use comparisons for more common attributes (e.g., date, age, sex).
matcher.define do
  join    :last,    :last_name,   1.0
  compare :age,     :age,         1.0  
end

# Do a fuzzy comparison on first name using Levenshtein edit distance. Currently there are a limited number of 
# built-in fuzzy comparison functions but these can easily be extended. The attribute being compared must 
# respond to 'similarity_to(l,r)' and return a float value from 0 to 1. 
# See custom rules below for more flexible options.
matcher.define do
  join    :last,    :last_name,   1.0
  compare :first,   :first_name,  1.0,  :fuzzy => true
end

# Use a lambda to perform the comparisons. The lambda must accept two arguments (left and right objects) and 
# return a score for the pair as a float. In this case, award 1.0 to each pair whose dates are within two days
# of each other.

within_two_days = lambda { |l,r| 1.0 if (l.date - r.date).abs <= 2 }

matcher.define do
  join    :amount,  :amount,  1.0
  custom  within_two_days
end
```

## Comments and Caveats

* The matcher is designed for 1:1 matching. You will need to fork and modify it for any other use.
Check out fuzzy_match for a different approach to rich, rules-based searching: https://github.com/seamusabshere/fuzzy_match
* Every object will be allocated to one of three resulting arrays: matches, left exceptions, and right exceptions. 
* There is no magic behind its decisions. Every object from the left store will be matched with the highest-possible
scoring match from the right store according to the rules you supply it.
* In cases where two or more left objects match the same right object with the same score, the object chosen for final match
assignment is arbitrary. The other left object(s) will be added to the left exceptions array.
* Rspec is your friend. Test your rules in the controlled environment of the test suite before deploying on production data.
* If you use it, I'd love to know what problem you're applying it to. Besides using it in my company, I also use it for reconciling my bank statement.

## Contributing to matching
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2012 Barry Ezell. MIT License:

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
