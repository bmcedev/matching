# Tests main functionality using array data stores and hash indexing.
# See ar_spec.rb for tests of ActiveRecord as the data store
# See redis_spec.rb for tests of Redis for indexing.

require 'date'
require File.expand_path("../../spec_helper", __FILE__)
include Matching

describe AttributePair do
  it "describes the relationship of two attributes from two classes for the matcher" do
    rab = AttributePair.new(:mid, :mid, 0.5)
    rab.left_attr.should == :mid
    rab.right_attr.should == :mid
    rab.weight.should == 0.5
    rab.is_fuzzy.should == false

    expect { AttributePair.new(:mid, :mid, 0.0) }.to raise_error
  end
end

describe HashIndex do
  it "indexes object ids for a given attribute and value" do
    subject.put(:mid, "7275551111", 1)
    subject.get(:mid, "7275551111").should == [1]
    subject.put(:mid, "7275551111", 2)
    subject.get(:mid, "7275551111").should == [1,2]
    subject.put(:mid, "8135554444", 3)
    subject.get(:mid, "8135554444").should == [3]
    subject.get(:mid, "2015558888").should be_nil
    subject.get(:esn, "1111111111").should be_nil
  end

  it "should not index nil values" do
    subject.put(:mid, nil, 1)
    subject.get(:mid, nil).should be_nil
  end
end

describe ArrayStore do
  include MatcherSpecHelper

  let(:left_as) { create_test_data; ArrayStore.new(@lefts) }
  let(:right_as) { create_test_data; ArrayStore.new(@rights) }

  it "should store data in left and right arrays" do
    left_as.arr.should have(3).items
    right_as.arr.should have(4).items
  end

  it "should enumerate left array objects with index" do
    cnt = 0
    expect { left_as.each { |o,idx| cnt += 1 } }.to change{cnt}.from(0).to(3)

    obj, id = nil, nil
    left_as.each do |o,idx|
      obj, id = o, idx
      break
    end

    id.should == 0
    obj.should == @left_a
  end

  it "should retrieve objects by their array index through the find method" do
    left_as.find(0).should == @left_a
    left_as.find(1).should == @left_b
    right_as.find(-1).should == @right_d
  end
end

describe Matcher do
  include MatcherSpecHelper

  let(:compare_string_size) { lambda { |l,r| (l.size == r.size ? 1.0 : 0.0) } }

  let(:esn_has_ones_filter) { lambda { |l,r| l.esn =~ /1/ && r.esn =~ /1/ } } 

  it "calculates non-fuzzy similarity of pairs of strings" do
    subject.compare_values("hello","hello").should == 1.0
    subject.compare_values("hello","world").should == 0.0
    subject.compare_values(nil,nil).should == 0.0
    subject.compare_values("hello",nil).should == 0.0
  end

  it "calculates fuzzy similarity of pairs of strings" do
    subject.compare_values("hello","hullo",:fuzzy => true).should be_within(0.1).of(0.75)
    subject.compare_values("hello","world",:fuzzy => true).should be_within(0.1).of(0.2)
    subject.compare_values("hello","zippy",:fuzzy => true).should be_within(0.1).of(0.0)
    subject.compare_values("John Q Public","Public,John", :fuzzy => true, :comparison => :name).should == 1.0
  end

  it "calculates non-fuzzy similarity of pairs of dates" do
    subject.compare_values(Date.new(2011,1,1),Date.new(2011,1,1)).should == 1.0
    subject.compare_values(Date.new(2011,1,1),Date.new(2011,1,2)).should == 0.0
  end

  it "calculates fuzzy similarity of pairs of dates" do
    subject.compare_values(Date.new(2011,1,1),Date.new(2011,1,2), :fuzzy => true).should be_within(0.1).of(0.9)
  end

  it "should raise exception if fuzzy comparison is requested on unsupported class" do
    expect { subject.compare_values(["cat"], ["bat"], :fuzzy => true) }.to raise_error(ArgumentError, "Cannot calculate fuzzy comparison for type Array")
  end

  it "should raise an exception if pairs for comparison are of different base types" do
    expect { subject.compare_values("hello",2) }.to raise_error
    expect { subject.compare_values(Date.new(2011,1,1),2) }.to raise_error
    expect { subject.compare_values(Date.new(2011,1,1),"world") }.to raise_error
  end

  it "creates AttributePairs using the join method" do
    expect { subject.join(:mid, :mid, 1.0) }.to change{ subject.join_pairs.size }.from(0).to(1)
  end

  it "creates AttributePairs using the compare method" do
    expect { subject.compare(:mid, :mid, 1.0) }.to change{ subject.compare_pairs.size }.from(0).to(1)
  end

  it "allows custom lambdas to be used for comparison rules" do
    expect { subject.custom(compare_string_size) }.to change{ subject.custom_functions.size }.from(0).to(1)
  end

  it "allows filters to be defined as custom lambdas that return boolean" do
    expect { subject.filter(esn_has_ones_filter) }.to change{ subject.filter_functions.size }.from(0).to(1)
  end

  it "defines the rules for matching through a define block" do
    subject.join_pairs.size.should == 0
    subject.compare_pairs.size.should == 0
    define_mid_esn_date_matcher(subject)
    subject.join_pairs.size.should == 2
    subject.compare_pairs.size.should == 1
  end

  it "scores two objects based on defined matching rules" do
    create_array_matcher
    define_mid_matcher(@matcher)
    @matcher.score_pair(@left_a,@right_b).should == 1.0
    @matcher.score_pair(@left_a,@right_a).should == 0.0

    @matcher.define { join :esn, :esn, 1.0 }
    @matcher.score_pair(@left_a,@right_b).should == 2.0
    @matcher.score_pair(@left_a,@right_a).should == 1.0

    @matcher.define { compare :date, :date, 0.5, :fuzzy => true }
    @matcher.score_pair(@left_a,@right_b).should == 2.5
    @matcher.score_pair(@left_a,@right_a).should == 1.5
    @matcher.score_pair(@left_c,@right_d).should be_within(0.1).of(1.5)

    lmbda = lambda { |l,r| (l.mid[0] == '7' ? 1.0 : 0.0) }
    @matcher.custom(lmbda)
    @matcher.score_pair(@left_a,@right_b).should == 3.5
  end

  it "requires left and right store objects be defined before matching" do
    m = Matching::Matcher.new(:left_store => nil, :right_store => nil)
    expect { m.match }.to raise_error(ArgumentError)
  end

  context "with hash index and array store" do

    before(:each) do
      create_array_matcher
    end

    it "requires at least one join pair to be defined" do
      expect { @matcher.index_right_objects }.to raise_error
    end

    context "using mid and esn matcher" do

      before(:each) do
        define_mid_esn_matcher(@matcher)
        @matcher.index_right_objects
      end

      it "indexes right records on join attributes" do
        @matcher.right_index.get(:esn, "11111111111").should_not be_nil
        @matcher.right_index.get(:esn, "11111111111").size.should == 2
        @matcher.right_index.get(:mid, "8135554444").size.should == 1
      end

      it "finds potential matches for left_objects from right_objects based on join criteria" do
        right_matches = @matcher.find_potential_matches(@left_a)
        right_matches.should have(3).items
        right_matches.should include(@right_a)
      end

      it "finds scored matches by applying rules after finding potential matches" do
        right_matches = @matcher.find_matches(@left_a)
        right_matches.should have(3).items

        #raise matching threshold
        @matcher.min_score = 2.0
        right_matches = @matcher.find_matches(@left_a)
        right_matches.should have(1).items

        #note: return value is an array of arrays, not an array of just
        #right_objects
        right_matches[0].should == [@right_b, 2.0]
      end
    end

    it "should reconcile test data based on single attribute pair" do
      define_esn_matcher(@matcher)
      @matcher.match
      @matcher.right_matches.size.should == 2
      @matcher.left_matches.size.should == 2

      @matcher.left_matches.should include(@left_a)
      @matcher.left_matches.should include(@left_b)
    end

    it "should reconcile test data based on two attribute pairs" do
      define_mid_esn_matcher(@matcher)
      @matcher.match
      @matcher.right_matches.size.should == 3
      @matcher.left_matches.size.should == 3

      create_array_matcher
      define_mid_esn_matcher(@matcher)
      @matcher.min_score = 2.0
      @matcher.match
      @matcher.right_matches.size.should == 2
      @matcher.left_matches.size.should == 2
    end

    it "should list non-matched objects as exceptions" do
      define_mid_esn_matcher(@matcher)
      @matcher.min_score = 2.0
      @matcher.match
      @matcher.left_exceptions.should have(1).item
      @matcher.right_exceptions.should have(2).items
    end

    it "should allow veto of matches using filtering rules" do
      create_array_matcher
      define_esn_matcher(@matcher)
      @matcher.filter(esn_has_ones_filter)
      @matcher.match
      @matcher.left_matches.size.should == 1
      @matcher.left_matches[@left_a].left_obj.esn.should =~ /1/
    end

  end #hash index and array store tests

  context "conflict resolution" do

    let(:amatcher) do

      #initially, A will match the first record it comes to (an outer record),
      #then A will be made loser and should eventually match Y
      @left_a =   Transaction.new(:id => 1, :esn => "11111111111", :mid => "cdcd")
      @left_b =   Transaction.new(:id => 2, :esn => "11111111111", :mid => "abab")
      @left_c =   Transaction.new(:id => 3, :esn => "11111111111", :mid => "yzyz")
      @lefts = [@left_a, @left_b, @left_c]

      @right_x =  Transaction.new(:id => 1, :esn => "11111111111", :mid => "abab")
      @right_y =  Transaction.new(:id => 2, :esn => "11111111111", :mid => "mnmn")
      @right_z =  Transaction.new(:id => 3, :esn => "11111111111", :mid => "yzyz")
      @rights = [@right_x, @right_y, @right_z]

      as_l = ArrayStore.new(@lefts)
      as_r = ArrayStore.new(@rights)
      matcher = Matching::Matcher.new(:left_store => as_l, :right_store => as_r)
      define_mid_esn_matcher(matcher)
      matcher
    end

    it "should find best fit for all objects" do
      amatcher.match
      amatcher.left_matches.should have(3).items
      amatcher.left_matches[@left_a].right_obj.should  == @right_y
      amatcher.left_matches[@left_a].score.should      == 1.0
      amatcher.left_matches[@left_b].right_obj.should  == @right_x
      amatcher.left_matches[@left_b].score.should      == 2.0
      amatcher.left_matches[@left_c].right_obj.should  == @right_z
      amatcher.left_matches[@left_c].score.should      == 2.0
    end

    it "should not find best fit unless evaluate_left_losers executes normally" do
      class << amatcher
        define_method(:evaluate_left_losers, proc { })
      end

      amatcher.match
      amatcher.left_matches.should have(2).items
      amatcher.left_matches[@left_b].right_obj.should  == @right_x
      amatcher.left_matches[@left_b].score.should      == 2.0
      amatcher.left_matches[@left_c].right_obj.should  == @right_z
      amatcher.left_matches[@left_c].score.should      == 2.0
    end

  end #conflict resolution

  #See ar_spec.rb and redis_spec.rb for tests involving ActiveRecord and Redis
end
