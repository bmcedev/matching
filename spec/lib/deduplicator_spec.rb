# Tests main functionality using array data stores and hash indexing.
# See ar_spec.rb for tests of ActiveRecord as the data store
# See redis_spec.rb for tests of Redis for indexing.

require 'rspec'
require 'date'
require File.expand_path(File.dirname(__FILE__) + '/../../lib/matching.rb')
include Matching

module DedupeSpecHelper
  CellTxn = Struct.new(:id, :mid, :esn, :act_date, :nilly)
end

describe Deduplicator do
  include DedupeSpecHelper

  let (:array_store) do
    c1 = CellTxn.new(0, "7275554444", "11111111111", Date.new(2011,1,1))
    c2 = CellTxn.new(1, "7275554444", "22222222222", Date.new(2011,1,2))
    c3 = CellTxn.new(2, "8135552222", "22222222222", Date.new(2011,1,3))
    c4 = CellTxn.new(3, "8135552222", "22222222222", Date.new(2011,1,2))
    ArrayStore.new([c1,c2,c3,c4])
  end

  before(:each) do
    @deduper = Deduplicator.new(array_store)
  end

  subject { @deduper }
  specify { subject.index.should_not be_nil }
  
  describe :store do
    context "when not empty" do
      specify { subject.store.should_not be_nil }
    end

    context "when empty" do
      specify { expect { Deduplicator.new }.to raise_error }
    end
  end

  describe "match criteria" do
    it "adds match definitions to criteria array" do
      subject.match_attrs([:mid])
      subject.criteria.should == [[:mid]]
    end

    it "should convert single items into arrays when adding criteria" do
      subject.match_attrs(:mid)
      subject.criteria.should == [[:mid]]
    end

    it "has a flattened, unique array combining any and all criteria" do
      subject.match_attrs([:mid, :esn])
      subject.match_attrs([:date, :mid])
      ua = subject.unique_attrs
      ua.should have(3).items
      ua.should include(:mid)
      ua.should include(:esn)
      ua.should include(:date)
    end

    it "calls any and all via a block" do
      subject.define do
        match_attrs [:mid, :esn]
        match_attrs [:date, :esn]
      end 

      subject.criteria.should == [[:mid, :esn], [:date, :esn]]
    end
  end

  it "indexes store values" do
    subject.define { match_attrs [:mid] }
    subject.create_index
    subject.index.get(:mid, "7275554444").should have(2).items
    subject.index.get(:mid, "8135552222").should have(2).items
    subject.index.get(:mid, "2055558888").should be_nil
  end

  describe "deduplicate" do
    context "single criteria arrays" do

      it "should deduplicate an ArrayStore on a single match criterion (1 of 3)" do
        subject.define do
          match_attrs   :mid 
        end

        subject.deduplicate
        subject.groups.count.should == 2
        subject.groups[0].count.should == 2
        subject.groups[1].count.should == 2
      end

      it "should deduplicate an ArrayStore on a single match criterion (2 of 3)" do
        subject.define do
          match_attrs   :esn
        end

        subject.deduplicate
        subject.groups.count.should == 2
        subject.groups[0].count.should == 1
        subject.groups[1].count.should == 3
      end

      it "should deduplicate an ArrayStore on a single match criterion (3 of 3)" do
        subject.define do
          match_attrs   :act_date
        end

        subject.deduplicate
        subject.groups.count.should == 3
      end

      it "should group with only nil values" do
        subject.define do
          match_attrs   :nilly
        end

        subject.deduplicate
        subject.groups.count.should == 1
      end

      it "should group with some nil values" do
        subject.define do
          match_attrs [:mid, :nilly]
        end

        subject.deduplicate
        subject.groups.count.should == 2
      end

      it "should deduplicate an ArrayStore on multiple criteria" do
        subject.define do
          match_attrs   [:esn, :act_date]
        end

        subject.deduplicate
        subject.groups.count.should == 3
      end
    end #single criteria arrays

    context "multiple criteria arrays" do

      let (:larger_array_store) do
        c1 = CellTxn.new(0, "7275554444", "11111111111", Date.new(2011,1,1))
        c2 = CellTxn.new(1, "7275554444", "22222222222", Date.new(2011,1,2))
        c3 = CellTxn.new(2, "8135552222", "22222222222", Date.new(2011,1,3))
        c4 = CellTxn.new(3, "8135552222", "22222222222", Date.new(2011,1,2))
        c5 = CellTxn.new(4, "7275554444", "11111111111", Date.new(2011,1,2)) #hybrid of c1 and c2
        ArrayStore.new([c1,c2,c3,c4,c5])
      end

      it "should join groups that are joined by different match criteria" do
        subject = Deduplicator.new(larger_array_store)
        subject.define do
          match_attrs   [:mid, :esn] #joins 0 and 4
          match_attrs   [:mid, :act_date] #joins 1 and 4
        end

        subject.deduplicate
        subject.groups.count.should == 2 # expect [0,1,4],[2,3]
        two_group = subject.groups.find { |grp| grp.size == 2}
        two_group.should include(2,3)
        three_group = subject.groups.find { |grp| grp.size == 3}
        three_group.should include(0,1,4)
      end

      it "should return results with objects, group index, and item index" do
        subject = Deduplicator.new(larger_array_store)
        subject.define do
          match_attrs   [:mid, :esn] #joins 0 and 4
          match_attrs   [:mid, :act_date] #joins 1 and 4
        end

        subject.deduplicate
        group_sum, item_sum = 0, 0
        subject.each_with_groups do |obj, grp_idx, item_idx|
          group_sum += grp_idx
          item_sum += item_idx
          #puts "grp: #{grp_idx}, item: #{item_idx}"
        end

        #grp: 0, item: 0
        #grp: 0, item: 1
        #grp: 0, item: 2
        #grp: 1, item: 0
        #grp: 1, item: 1

        group_sum.should == 2
        item_sum.should == 4
      end
    end #multiple criteria arrays
  end #deduplication

  context "integration tests" do

    it "should deduplicate on a common key" do
      txns = []
      i = 0
      File.open(File.join(File.dirname(__FILE__),'/../samples/agent_recs.csv'),'r').each do |line|
        parts = line.split ','
        txns << CellTxn.new(parts[0],parts[1],parts[2],parts[3])

        i += 1
        break if i == 200
      end       

      subject = Deduplicator.new(ArrayStore.new(txns))
      subject.define do
        match_attrs :act_date
      end

      subject.deduplicate

      dates = txns.map { |txn| txn.act_date } 

      subject.groups.size.should == dates.uniq.count
    end
  end #integration
end
