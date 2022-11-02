# frozen_string_literal: true
require 'toolrack'
require 'teLogger'

require_relative "statize/version"

module Statize
  class Error < StandardError; end
  class InvalidStatus < StandardError; end
  class InvalidStatusForEvent < StandardError; end
  class UserHalt < StandardError; end
  
  include TR::CondUtils

  include TeLogger::TeLogHelper
  teLogger_tag :statize

  # class methods start here
  module ClassMethods
   
    def stateful(opts = {  })
      @ops = {
        initial_state: :open,
        state_attr_name: "state",
      } 

      @ops.merge!(opts) if not opts.nil? and opts.is_a?(Hash)

      @ops[:states_table] = {}
      @ops[:state_events] = {}
      @ops[:event_states] = {}
      @ops[:event_block] = {}

    end

    def event(evt, *args, &block)
      
      evt = evt.to_sym
      @ops[:event_states][evt] = {} if @ops[:event_states][evt].nil?
      @ops[:event_block][evt] = block if block

      args.first.each do |fromSt, toSt|
        fromSt = fromSt.to_sym
        toSt = toSt.to_sym
        @ops[:state_events][fromSt] = [] if @ops[:state_events][fromSt].nil?
        @ops[:state_events][fromSt] << evt

        @ops[:states_table][fromSt] = [] if @ops[:states_table][fromSt].nil?
        @ops[:states_table][fromSt] << toSt if not @ops[:states_table][fromSt].include?(toSt)

        @ops[:event_states][evt][fromSt] = toSt
      end

    end

    def state_attr_name
      @ops[:state_attr_name].to_s.freeze
    end

    def initial_state
      @ops[:initial_state].to_s.freeze
    end

    def states_table
      @ops[:states_table].freeze
    end

    def state_events_table
      @ops[:state_events].freeze
    end

    def event_states_table
      @ops[:event_states].freeze
    end

    def event_block_table
      @ops[:event_block].freeze
    end

  end
  def self.included(klass)
    klass.extend(ClassMethods)
  end
  # end class methods

  def init_state
    update_state(self.class.initial_state)
  end

  def next_states
    st = current_state
    if not_empty?(st)
      self.class.states_table[st.to_sym].map { |e| e.to_s }
    else
      []
    end
  end

  def apply_state(st)
    
    case st
    when Symbol
      sst = st
    else
      sst = st.to_sym
    end

    if next_states.include?(sst.to_s)
      update_state(sst)
      true
    else
      false
    end
  end
  def apply_state!(st)
    res = apply_state(st)
    raise InvalidStatus, "Given new state '#{st}' is not valid" if not res
  end


  def next_events
    se = self.class.state_events_table
    cst = current_state
    se[cst.to_sym]
  end

  def trigger_event(evt)
    evt = evt.to_sym if not evt.nil?
    cst = current_state
    if not_empty?(cst)
      cst = cst.to_sym
      tbl = self.class.event_states_table[evt]

      if tbl.keys.include?(cst)
        destSt = tbl[cst]
        if not_empty?(destSt)
          
          evtBlock = self.class.event_block_table[evt]
          update = true
          
          if not evtBlock.nil?
            update = evtBlock.call(evt, cst, destSt)
          end

          update = true if is_empty?(update) or not_bool?(update)

          if update
            apply_state(tbl[cst.to_sym])
          else
            teLogger.error "Event '#{evt}' triggered but block returned false. Status not updated to '#{destSt}'"
            raise UserHalt,"Event '#{evt}' triggered but block returned false. Status not updated to '#{destSt}'"
          end

        end
      else
        # current state not tie to from state of this event
        raise InvalidStatusForEvent, "Current state '#{cst}' does not register as source state for event '#{evt}'"
      end

    else
      # current state is empty!
    end
  end

  def current_state
    if has_rattr?(self.class.state_attr_name)
      self.send("#{self.class.state_attr_name}")
    else
      nil
    end
  end

  private
  def has_wattr?(key)
    self.respond_to?("#{key}=".to_sym)
  end
  def has_rattr?(key)
    self.respond_to?("#{key}".to_sym)
  end

  def update_state(st)
    if has_wattr?(self.class.state_attr_name)
      self.send("#{self.class.state_attr_name}=", st.to_s) 
    end
  end

  # instance methods

end
