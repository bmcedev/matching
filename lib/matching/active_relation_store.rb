require 'active_record'

module Matching

  #Stores and retrieves data from ActiveRelation for Matcher
  class ActiveRelationStore

    attr_reader :model, :where_clause

    def initialize(model, where_clause = nil)
      @model = model
      @where_clause = where_clause
    end

    #Iterates over array, also returning id
    def each(&blk)
      @model.where(@where_clause).find_in_batches do |group|
        group.each do |obj|
          blk.yield(obj, obj.id)
        end
      end
    end

    #Return an object by its AR id
    def find(id)
      @model.find(id)
    end

  end
end
