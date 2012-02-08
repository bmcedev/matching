require 'rspec'

require File.join(File.dirname(__FILE__), '../lib/matching.rb')

module MatcherSpecHelper

  REDIS_TEST_DB = 8

  class Transaction
    attr_accessor :id, :esn, :mid, :date

    def initialize(opts)
      opts.each do |key,value|
        instance_variable_set "@#{key}", value
      end
    end
  end

  # Creates arrays of Transaction objects
  def create_test_data
    @left_a = Transaction.new(:esn => "11111111111", :mid => "7275551111", :date => Date.new(2010,6,1))
    @left_b = Transaction.new(:esn => "22222222222", :mid => "8135554444", :date => Date.new(2010,6,1))
    @left_c = Transaction.new(:esn => "33333333333", :mid => "7275551111", :date => Date.new(2010,6,15))
    @lefts = [@left_a, @left_b, @left_c] 

    @right_a = Transaction.new(:esn => "11111111111", :mid => "2015559999", :date => Date.new(2010,6,1))
    @right_b = Transaction.new(:esn => "11111111111", :mid => "7275551111", :date => Date.new(2010,6,1))
    @right_c = Transaction.new(:esn => "22222222222", :mid => "8135554444", :date => Date.new(2010,6,2))
    @right_d = Transaction.new(:esn => "44444444444", :mid => "7275551111", :date => Date.new(2010,6,14))
    @rights = [@right_a, @right_b, @right_c, @right_d]

    #Match chart                esn   mid   txn_date
    #--------------------------------------------------------------
    #left_a        right_b      X     X     X
    #left_a        right_a      X           X
    #left_b        right_c      X     X
    #left_c        right_d            X     (delta 1)
    #
    #right_a the same as right_b except for mid
  end

  def define_mid_matcher(m)
    m.define { join :mid, :mid, 1.0 }
  end

  def define_esn_matcher(m)
    m.define { join :esn, :esn, 1.0 }
  end

  def define_mid_esn_matcher(m)
    define_mid_matcher(m)
    m.define { join :esn, :esn, 1.0 }
  end

  def define_mid_esn_date_matcher(m)
    define_mid_esn_matcher(m)
    m.define { compare :date, :date, 0.5, :fuzzy => true }
  end
  
  # Matcher using arrays for the data store
  def create_array_matcher(opts={})

    create_test_data
    @matcher = Matcher.new(:left_store => ArrayStore.new(@lefts), 
                           :right_store => ArrayStore.new(@rights),
                           :redis_db => (opts[:use_redis] ? REDIS_TEST_DB : -1) 
                          )
  end

end
