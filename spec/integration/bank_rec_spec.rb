require File.expand_path("../../spec_helper", __FILE__)
include Matching

# Note: do not use a Struct in place of the class because matcher.rb relies
# on object_id for determine object inclusion in exception arrays. Two
# instances of a Struct with the same values have the same object_id.
class Transaction
  attr_accessor :date, :desc, :amount
  def initialize(date, desc, amount)
    @date, @desc, @amount = date, desc, amount     
  end
end

describe "Bank reconciliation" do

  let(:ledger_txns) do
    [
      Transaction.new(Date.new(2012,1,1),'Basecamp','25.0'),
      Transaction.new(Date.new(2012,1,1),'Basecamp','25.0'),
      Transaction.new(Date.new(2012,1,2),'Github','25.0')
    ]
  end

  let(:bank_txns) do
    [
      Transaction.new(Date.new(2012,1,1),'Basecamp (37 signals)','25.0'),
      Transaction.new(Date.new(2012,1,3),'Github','25.0')
    ]
  end

  let(:matcher) do
    Matching::Matcher.new(
      :left_store => ArrayStore.new(ledger_txns),
      :right_store => ArrayStore.new(bank_txns),
      :min_score => 1.0
    )
  end

  it "should rec" do
    matcher.define do
      join  :amount,  :amount, 1.0
      compare :date,  :date, 0.2, :fuzzy => true
    end
    matcher.match 
    matcher.left_matches.should have(2).items
    matcher.left_exceptions.should have(1).items
    matcher.right_exceptions.should have(0).items
  end

end
