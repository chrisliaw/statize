# frozen_string_literal: true
require 'toolrack'
require 'teLogger'

require_relative "statize/version"

module Statize
  class Error < StandardError; end
  class InvalidState < StandardError; end
  class InvalidStateForEvent < StandardError; end
  class UserHalt < StandardError; end
  class InvalidEvent < StandardError; end
  
  include TR::CondUtils

  include TeLogger::TeLogHelper
  teLogger_tag :statize

  # class methods start here
  module ClassMethods
   
    def stateful(opts = {  }, &block)
      @ops = {  } if @ops.nil?
      ops = {
        initial_state: :open,
        state_attr_name: "state",
      } 

      @profile = opts[:profile] || :default 

      opts.delete(:profile)

      ops.merge!(opts) if not opts.nil? and opts.is_a?(Hash)

      @ops[@profile] = {  }
      @ops[@profile].merge!(ops)

      if block
        class_eval(&block)
      end

    end

    # definition of event
    # Using global parameter @profile during definition
    def event(evt, *args, &block)
      
      evt = evt.to_sym
      add_event_block(@profile, evt, &block)

      args.first.each do |fromSt, toSt|
        fromSt = fromSt.to_sym
        toSt = toSt.to_sym
        add_state_events(@profile,fromSt, evt)
        add_state_transition(@profile, fromSt, toSt)
        add_event_states(@profile, evt, fromSt, toSt)
      end

    end

    def state_attr_name(prof = :default)
      @ops[prof][:state_attr_name].to_s.freeze
    end

    def initial_state(prof = :default)
      @ops[prof][:initial_state].to_s.freeze
    end

    def states_table(prof = :default)
      _states_transfer_table(prof).freeze
    end

    def state_events_table(prof = :default)
      _state_events_table(prof).freeze
    end

    def event_states_table(prof = :default)
      _event_states_table(prof).freeze
    end

    def event_block_table(prof = :default)
      _event_block_table(prof).freeze
    end

    private
    # keep possible next states
    def add_state_transition(prof, from, to)
      _states_transfer_table(prof)[from] = [] if _states_transfer_table(prof)[from].nil?
      # ok to keep single relationship as this table hold the possible next states,
      # which is possible duplicate but different event
      _states_transfer_table(prof)[from] << to if not _states_transfer_table(prof)[from].include?(to)
    end

    # keep state (current state) mapping to possible events
    def add_state_events(prof, from, evt)
      _state_events_table(prof)[from] = [] if _state_events_table(prof)[from].nil?
      _state_events_table(prof)[from] << evt
    end

    # keep complete event, from and to state
    def add_event_states(prof, evt, fromSt, toSt)
      _event_states_table(prof)[evt] = {} if _event_states_table(prof)[evt].nil?
      _event_states_table(prof)[evt][fromSt] = toSt
    end

    def add_event_block(prof, evt, &block)
      _event_block_table(prof)[evt] = block if block
    end

    def _states_transfer_table(prof = :default)
      #@ops[prof] = {} if @ops[prof].nil?
      @ops[prof][:state_transfer] = {} if @ops[prof][:state_transfer].nil?
      @ops[prof][:state_transfer]
    end

    def _state_events_table(prof = :default)
      #@ops[prof] = {} if @ops[prof].nil?
      @ops[prof][:state_events] = {} if @ops[prof][:state_events].nil?
      @ops[prof][:state_events]
    end

    def _event_states_table(prof = :default)
      #@ops[prof] = {} if @ops[prof].nil?
      @ops[prof][:event_states] = {} if @ops[prof][:event_states].nil?
      @ops[prof][:event_states]
    end

    def _event_block_table(prof = :default)
      #@ops[prof] = {} if @ops[prof].nil?
      @ops[prof][:event_block_table] = {} if @ops[prof][:event_block_table].nil?
      @ops[prof][:event_block_table]
    end

  end
  def self.included(klass)
    klass.extend(ClassMethods)
  end
  # end class methods


  # 
  # instance methods
  #
  def init_state(prof = :default)
    set_active_profile(prof)
    update_state(self.class.initial_state(prof))
  end

  def activate_state_profile(prof)
    set_active_profile(prof)
    update_state(self.class.initial_state(prof))
  end

  def next_states
    st = current_state
    if not_empty?(st)
      self.class.states_table(active_profile)[st.to_sym].map { |e| e.to_s }
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
    raise InvalidState, "Given new state '#{st}' is not valid" if not res
  end


  def next_events
    se = self.class.state_events_table(active_profile)
    cst = current_state
    se[cst.to_sym]
  end

  def trigger_event(evt)
    evt = evt.to_sym if not evt.nil?
    cst = current_state
    if not_empty?(cst)
      cst = cst.to_sym
      tbl = self.class.event_states_table(active_profile)[evt]

      raise InvalidEvent, "Event '#{evt}' not registered under profile '#{active_profile}'" if tbl.nil?

      # current state not tie to from state of this event
      raise InvalidStateForEvent, "Current state '#{cst}' is not register to event '#{evt}'" if not tbl.keys.include?(cst)
      
      destSt = tbl[cst]
      raise InvalidStateForEvent, "New state transition from current state '#{cst}' due to event '#{evt}' is empty" if is_empty?(destSt)

      evtBlock = self.class.event_block_table(active_profile)[evt]
      update = true

      update = evtBlock.call(:before, evt, cst, destSt) if not evtBlock.nil?
      update = true if is_empty?(update) or not_bool?(update)

      if update
        apply_state(destSt)
        evtBlock.call(:after, evt, cst, destSt) if not evtBlock.nil?
      else
        teLogger.error "Event '#{evt}' triggered but block returned false. Status not updated to '#{destSt}'"
        raise UserHalt,"Event '#{evt}' triggered but block returned false. Status not updated to '#{destSt}'"
      end

    else
      # current state is empty!
    end
  end

  def current_state
    if has_rattr?(self.class.state_attr_name(active_profile))
      self.send("#{self.class.state_attr_name(active_profile)}")
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
    if has_wattr?(self.class.state_attr_name(active_profile))
      self.send("#{self.class.state_attr_name(active_profile)}=", st.to_s) 
    end
  end

  def active_profile
    @aprof = :default if is_empty?(@aprof)
    @aprof
  end

  def set_active_profile(val)
    @aprof = val
  end

  # instance methods

end
