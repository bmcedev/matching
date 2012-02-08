# Tests Redis as the indexer

require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../../../lib/matching/redis_index", __FILE__)

include Matching

def test_redis_connection
  r = Redis.new
  r.inspect rescue puts "Start Redis to run redis_spec" and return false
end

if test_redis_connection
  describe RedisIndex do
    it "index object ids for a given attribute and value" do
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

  describe Matcher do
    include MatcherSpecHelper

    context "with redis index and array store" do

      before(:each) do
        create_array_matcher(:use_redis => true)
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

        create_array_matcher(:use_redis => true)
        @matcher.min_score = 2.0
        define_mid_esn_matcher(@matcher)
        @matcher.match
        @matcher.right_matches.size.should == 2
        @matcher.left_matches.size.should == 2
      end

    end #redis index and array store tests
  end
end #test redis cnn
