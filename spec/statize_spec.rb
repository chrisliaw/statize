# frozen_string_literal: true

RSpec.describe Statize do
  it "has a version number" do
    expect(Statize::VERSION).not_to be nil
  end

  it 'includes into any class for stateful operations' do
    
    class Target
      include Statize

      attr_accessor :state

      stateful initial: :open

      event :close, :open => :closed 
      event :kiv, :open => :kiv, :closed => :kiv 
      event :reopen, :kiv => :open do |stage, evt, from, to|
        puts "stage : #{stage} / event #{evt} == reopen / #{from} / #{to}"
      end

      # stage : :before or :after state change
      # evt : current event
      # from : current state
      # to : next state as configure in event() above
      event :archive, :closed => :archived do |stage, evt, from, to|
        puts "stage : #{stage} / event #{evt} == reopen / #{from} / #{to}"
        false
      end

      def initialize
        init_state
      end

    end

    t = Target.new
    expect(t.state == "open").to be true

    evt = t.next_events
    expect(evt.is_a?(Array)).to be true

    t.trigger_event(:close)
    expect(t.current_state == "closed").to be true

    t.trigger_event(:kiv)
    expect(t.current_state == "kiv").to be true

    t.trigger_event(:reopen)
    expect(t.current_state == "open").to be true

    t.trigger_event(:kiv)
    expect {
      t.trigger_event(:close)
    }.to raise_exception(Statize::InvalidStateForEvent)

    t.trigger_event(:reopen)

    st = t.next_states
    expect(st.is_a?(Array)).to be true

    res = t.apply_state(:notsure)
    expect(res).to be false
    expect(t.state == "open").to be true
    res = t.apply_state(:closed)
    expect(res).to be true
    expect(t.state == "closed").to be true
    expect(t.next_states.include?("kiv")).to be true


    expect{ 
      t.trigger_event(:archive)
    }.to raise_exception(Statize::UserHalt)

  end

  it 'includes into any class for stateful operations with non standard state field name' do
    
    class Target
      include Statize

      attr_accessor :stat

      stateful initial: :open, state_attr_name: :stat

      event :close, :open => :closed 
      event :kiv, :open => :kiv, :closed => :kiv 
      event :reopen, :kiv => :open 

      event :archive, :closed => :archived do |evt, from, to|
        puts "event #{evt} == reopen / #{from} / #{to}"
        false
      end

      def initialize
        init_state
      end

    end

    t = Target.new
    expect(t.current_state == "open").to be true

    evt = t.next_events
    expect(evt.is_a?(Array)).to be true

    t.trigger_event(:close)
    expect(t.current_state == "closed").to be true

    t.trigger_event(:kiv)
    expect(t.current_state == "kiv").to be true

    t.trigger_event(:reopen)
    expect(t.current_state == "open").to be true

    t.trigger_event(:kiv)
    expect {
      t.trigger_event(:close)
    }.to raise_exception(Statize::InvalidStateForEvent)

    t.trigger_event(:reopen)

    st = t.next_states
    expect(st.is_a?(Array)).to be true

    res = t.apply_state(:notsure)
    expect(res).to be false
    expect(t.current_state == "open").to be true
    res = t.apply_state(:closed)
    expect(res).to be true
    expect(t.current_state == "closed").to be true
    expect(t.next_states.include?("kiv")).to be true


    expect{ 
      t.trigger_event(:archive)
    }.to raise_exception(Statize::UserHalt)

  end

  it 'has separate profiles' do
    
    class Target
      attr_accessor :st, :cst

      include Statize

      stateful initial_state: :logged, state_attr_name: :st do
        event :fire_up, :logged => :dislodged
      end

      stateful profile: :first, initial_state: :open, state_attr_name: :st do
        event :kick_start, :open => :start
      end

      stateful profile: :second, initial_state: :active, state_attr_name: :cst do
        event :init, :active => :burnt
      end

      #def initialize
      #  init_state
      #end

    end

    t = Target.new
    # default profile
    expect(t.current_state == "logged").to be true

    t.activate_state_profile(:first)
    expect(t.current_state == "open").to be true
    expect(t.st == "open").to be true

    t.activate_state_profile(:second)
    expect(t.current_state == "active").to be true
    expect(t.st == "open").to be true
    expect(t.cst == "active").to be true

    t.activate_state_profile(:first)
    t.trigger_event(:kick_start)
    expect(t.current_state == "start").to be true
    expect(t.st == "start").to be true
    expect(t.cst == "active").to be true

    t.activate_state_profile(:second)
    t.trigger_event(:init)
    expect(t.current_state == "burnt").to be true
    expect(t.st == "start").to be true
    expect(t.cst == t.current_state).to be true

  end

end
