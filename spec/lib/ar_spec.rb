# Tests ActiveRecord as the data store

require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../../../lib/matching/active_relation_store", __FILE__)
include Matching

module ArSpecHelper

  class Txn < ActiveRecord::Base
  end

  def config
    @config ||= YAML.load_file(File.expand_path(File.dirname(__FILE__) + '/../db/database.yml'))['development']
  end

  def db_connect
    File.delete(config['database']) if File.exists?(config['database'])
    options = {:charset => 'utf8', :collation => 'utf8_unicode_ci'}
    ActiveRecord::Base.establish_connection config
    sql = "create table txns(id integer primary key, company text, esn text, mdn text, date date);"
    ActiveRecord::Base.connection.execute(sql)
  end

  #creates arrays of Transaction and ServiceChange model objects using similar structure to
  #create_test_data above
  def create_ar_test_data
    db_connect

    @left_a = Txn.create(:company => 'ACME', :esn => "11111111111", :mdn => "7275551111", :date => Date.new(2010,6,1))
    @left_b = Txn.create(:company => 'ACME', :esn => "22222222222", :mdn => "8135554444", :date => Date.new(2010,6,1))
    @left_c = Txn.create(:company => 'ACME', :esn => "33333333333", :mdn => "7275551111", :date => Date.new(2010,6,15))

    @right_a = Txn.create(:company => 'Cinco', :esn => "11111111111", :mdn => "2015559999", :date => Date.new(2010,6,1))
    @right_b = Txn.create(:company => 'Cinco', :esn => "11111111111", :mdn => "7275551111", :date => Date.new(2010,6,1))
    @right_c = Txn.create(:company => 'Cinco', :esn => "22222222222", :mdn => "8135554444", :date => Date.new(2010,6,2))
    @right_d = Txn.create(:company => 'Cinco', :esn => "44444444444", :mdn => "7275551111", :date => Date.new(2010,6,14))
  end

  #matcher using ActiveRecord for the data store
  def create_ar_matcher(use_redis = false)
    create_ar_test_data

    matcher = Matcher.new(
                            :left_store => ActiveRelationStore.new(Txn, "company = 'ACME'"),
                            :right_store => ActiveRelationStore.new(Txn, "company = 'Cinco'"),
                            :redis_db => (use_redis ? 8 : nil)
                          )
  end
end

describe ActiveRelationStore do
  include ArSpecHelper

  before(:each) do
    create_ar_test_data
  end

  context " unfiltered" do
    let(:store) { ActiveRelationStore.new(Txn) }

    it "should enumerate left AR objects with id" do
      cnt = 0
      expect { store.each { |o,idx| cnt += 1 } }.to change{cnt}.from(0).to(7)

      obj, id = nil, nil
      store.each do |_obj,_id|
        obj, id = _obj, _id
        break
      end

      id.should == 1
      obj.should == @left_a
    end

    it "should retrieve objects by their id through the find method" do
      store.find(2).should == @left_b
    end
  end

  context " filtered" do
    let(:store) { ActiveRelationStore.new(Txn, "company = 'Cinco'") }

    it "should have a where clause" do
      store.where_clause.should == "company = 'Cinco'"
    end

    it "should enumerate left AR objects from query with where clause" do
      cnt = 0
      expect { store.each { |o,idx| cnt += 1 } }.to change{cnt}.from(0).to(4)
    end
  end
end

describe Matcher do
  include ArSpecHelper

  context "with hash index and ActiveRecord store" do

    before(:each) do
      @matcher = create_ar_matcher
    end

    let(:esn_matcher) do
      @matcher.define { join :esn, :esn, 1.0 }
    end

    let(:ptn_esn_matcher) do
      @matcher.define do
        join :mdn, :mdn, 1.0 
        join :esn, :esn, 1.0
      end
    end

    it "requires at least one join pair to be defined" do
      expect { @matcher.index_right_objects }.to raise_error
    end

    context "using ptn and esn matcher" do

      before(:each) do
        ptn_esn_matcher
        @matcher.index_right_objects
      end

      it "indexes right records on join attributes" do
        @matcher.right_index.get(:esn, "11111111111").should_not be_nil
        @matcher.right_index.get(:esn, "11111111111").size.should == 2
        @matcher.right_index.get(:mdn, "8135554444").size.should == 1
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
      esn_matcher
      @matcher.match
      @matcher.right_matches.size.should == 2
      @matcher.left_matches.size.should == 2

      @matcher.left_matches.should include(@left_a)
      @matcher.left_matches.should include(@left_b)
      @matcher.left_matches[@left_b].right_obj.should == @right_c
    end

    it "should reconcile test data based on two attribute pairs" do
      ptn_esn_matcher
      @matcher.match
      @matcher.right_matches.size.should == 3
      @matcher.left_matches.size.should == 3
      @matcher.left_matches[@left_c].right_obj.should == @right_d
    end

    it "should fail to match records below the min_score threshold" do
      ptn_esn_matcher
      @matcher.min_score = 2.0
      @matcher.match
      @matcher.right_matches.size.should == 2
      @matcher.left_matches.size.should == 2
      @matcher.left_matches[@left_c].should be_nil
    end

  end #hash index and ActiveRecord tests

end
