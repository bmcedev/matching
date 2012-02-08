# matching

Matching is a library for performing rules-based matches between records in two
datasets. These datasets are typically from two different sources that pertain
to the same or similar set of transactions. This library allows you to compare
the datasets and produces an array of matched records as well as an array of
exceptions (nonmatches) for each input dataset.

Matching is designed primarily for reconciliations. Example use cases:

* Bank reconciliations, where input datasets come from an accounting system and an
  online bank statement.

* Cellular commission reconciliation, where input datasets come from an
  independent retailer's Point Of Sale system and a carrier's commission
statement.

A library like this is obviously no replacement for database joins on a
properly-designed RDBMS. However, there are many real-world situations where
the programmer must handle data from different sources that are nonetheless
similar. It's meant to help answer the basic question, "is there agreement
between these two sets of records and where to they differ?".

## Example

To illustrate how Matching is useful in situations where a database join can
lead to errors, take the example of reconciling a bank statement against an
accounting system's transactions. In this example, the bookeeper incorrectly
recorded a transaction twice.

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

If using a database approach, you might load the datasets into two tables,
"ledger" and "bank" then join on amount:

  select * from ledger a join bank b on a.amount = b.amount;

  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-01|Basecamp|25.0|2012-01-03|Github|25.0  
  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-01|Basecamp|25.0|2012-01-03|Github|25.0  
  2012-01-02|Github|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-02|Github|25.0|2012-01-03|Github|25.0  

That's clearly not the right answer. Because amount was the only criterion
used for joining, the result joins each record with a $25 value, with 2*3
records as a result.

OK, how about adding in the date:

  select * from ledger a join bank b on a.amount = b.amount and a.date = b.date;

  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  

Still incorrect because the bookeeper recorded the Github transaction on Jan. 2
and the bank shows the debit on Jan. 3. How about using description and amount?

  select * from ledger a join bank b on a.amount = b.amount and a.description = b.description;

  2012-01-02|Github|25.0|2012-01-03|Github|25.0

Even worse. Because two different people or systems entered these records, they
have slightly different descriptions. Now you might try some more complidated SQL:

  select * from ledger a join bank b on a.amount = b.amount and (a.description = b.description or a.date = b.date);

  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0  
  2012-01-02|Github|25.0|2012-01-03|Github|25.0  

At first blush that might look right, but because there are two bank statement
lines, a correctly matched result dataset may not contain more than two
records. What we want is this:

  2012-01-01|Basecamp|25.0|2012-01-01|Basecamp (37 signals)|25.0    
  2012-01-02|Github|25.0|2012-01-03|Github|25.0  

### Solution using Matching




  
  
  


  

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
