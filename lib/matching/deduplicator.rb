module Matching
  class Deduplicator

    attr_accessor :store, :index, :criteria
    attr_accessor :groups   # array of arrays of duplicate records in form [[1,5],[2,3,4],[6]]
    attr_accessor :grouped  # hash of all ids present in @groups. Eventually all ids from @store will be added.
                            # Stored in form { id => index_of_groups_object }

    def initialize(store,opts={})
      raise 'Store parameter required' unless store
      @store = store

      @criteria = []
     
      # Create an index using either a hash or Redis as the backing store
      if opts[:redis_db] && opts[:redis_db].to_i >= 1
        @index = RedisIndex.new(opts[:redis_db])
      else
        @index = HashIndex.new
      end
    end

    def match_attrs(attrs)
      @criteria << [*attrs] #converts to array if not already, doesn't affect arrays  
    end

    def unique_attrs
      @criteria.flatten.uniq
    end

    def define(&block)
      instance_eval(&block)
    end

    def deduplicate
      @groups = []      # Array of arrays containing ids of grouped objects
      @nil_group = []   # Special array of objects whose indexed values are all nil (because index isn't tracking them)
      @grouped = {}     # Hash of each object's id to the index of @groups in which its found
      
      # Index all records in the store to speed search
      create_index

      # Place each object into an array in @groups that contain all
      # records that match the defined matching logic.
      @store.each do |obj,store_idx|

        puts "On #{store_idx}" if store_idx % 100 == 0 && store_idx > 0

        # Shortcut the process if there is only one array in criteria 
        # and this object is already present (because it can't possibly match
        # a second time)
        next if @criteria.size == 1 && @grouped[obj.id]

        @criteria.each do |arr|

          # Find matching objects
          all_matches = nil
          arr.each do |match_attr|
            val = obj.send(match_attr)

            if val != nil
              matches = @index.get(match_attr, val)
              all_matches = (all_matches ? all_matches & matches : matches)
            end
          end

          if all_matches.nil?
            @nil_group << obj.id
            next
          end

          # Assign matched objects to a group.
          # Groups may be merged in this process. 
          current_group_indexes = all_matches.inject([]) do |arr,id| 
            arr << @grouped[id] if @grouped[id] 
            arr
          end.uniq.compact

          next if current_group_indexes.size == 1 # can only be [obj_id]

          if current_group_indexes.size > 1
            # Merge related groups into mega_group based on first group
            mega_group = @groups[current_group_indexes[0]] 
            current_group_indexes[1..-1].each do |idx| 
              @groups[idx].each { |id| mega_group << id } 
              @groups.delete_at(idx)
            end
          
            # Re-assign @grouped for all objects to new mega-group
            mega_group.each { |obj_id| @grouped[obj_id] = current_group_indexes[0] }
          else
            # Create new group
            @groups << all_matches
            group_idx = @groups.size - 1
            all_matches.each { |obj_id| @grouped[obj_id] = group_idx }
          end
        end   
      end

      # Add the contents of nil group as a single group
      @groups << @nil_group if @nil_group.any?

      #puts "Results: #{@groups.inspect}"
    end

    def create_index
      raise 'Deduplicator requires at least one match attribute be defined' unless @criteria.any?

      @store.each do |obj, id|
        unique_attrs.each do |ma|
          @index.put(ma, obj.send(ma), id)
        end
      end
    end

    # Returns each object in store along with its group's index and index within
    # the group. For example...
    # group_idx | idx | name
    #         0 |   0 | Fred Smith
    #         0 |   1 | Fred Smith
    #         1 |   0 | Jane Green
    #         2 |   0 | Linda Smythe
    #         2 |   1 | Linda Smythe
    def each_with_groups
      @groups.each_with_index do |arr,grp_idx|
        arr.each_with_index do |obj_id,obj_idx|
          yield(@store.find(obj_id), grp_idx, obj_idx) 
        end
      end
    end

  end # class
end # module
