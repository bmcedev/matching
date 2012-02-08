require 'redis'

module Matching
  class RedisIndex

    def initialize(db_num=8)
      @redis = Redis.new
      @redis.select(db_num)
      @redis.flushdb
    end

    #Add a value to the index for a given attribute and object id
    def put(attr, val, id)
      unless val.nil?
        @redis.sadd("#{attr}:#{val}",id)
      end
    end

    #Return an array of object ids for a given attribute and value
    def get(attr, val)
      str_ids = @redis.smembers("#{attr}:#{val}")
      (str_ids.any? ? str_ids.map { |a| a.to_i } : nil)
    end

  end
end
