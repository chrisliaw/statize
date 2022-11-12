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
      event :reopen, :kiv => :open do |params|
        puts "stage : #{params[:action]} / event #{params[:event]} == reopen / #{params[:from_state]} / #{params[:to_state]}"
      end

      # stage : :before or :after state change
      # evt : current event
      # from : current state
      # to : next state as configure in event() above
      event :archive, :closed => :archived do |params|
        puts "stage : #{params[:action]} / event #{params[:event]} == archive / #{params[:from_state]} / #{params[:to_state]}"
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

      event :archive, :closed => :archived do |params|
        puts "stage : #{params[:action]} / event #{params[:event]} == archive / #{params[:from_state]} / #{params[:to_state]}"
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
        event :cool_down, :dislodged => :logged
        event :init, :logged => :inited

        # arbitary mapping allow user to define under the domain and later retrieve it
        # for other usage
        state_meaning :dislodged => :record_locked, :inited => :record_locked, :logged => :nothing
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
    expect(t.current_state_meaning == :nothing).to be true

    t.trigger_event(:fire_up)
    expect(t.current_state == "dislodged").to be true
    expect(t.current_state_meaning == :record_locked).to be true

    t.trigger_event(:cool_down)
    expect(t.current_state == "logged").to be true
    expect(t.current_state_meaning == :nothing).to be true

    som = t.states_of_meaning(:record_locked)
    expect(som.length == 2).to be true
    expect(som.include?(:dislodged) && som.include?(:inited)).to be true

    t.init_state(:first)
    expect(t.current_state == "open").to be true
    expect(t.st == "open").to be true

    t.init_state(:second)
    expect(t.current_state == "active").to be true
    expect(t.st == "open").to be true
    expect(t.cst == "active").to be true

    t.init_state(:first)
    t.trigger_event(:kick_start)
    expect(t.current_state == "start").to be true
    expect(t.st == "start").to be true
    expect(t.cst == "active").to be true

    t.init_state(:second)
    t.trigger_event(:init)
    expect(t.current_state == "burnt").to be true
    expect(t.st == "start").to be true
    expect(t.cst == t.current_state).to be true

    expect(t.state_profiles.include?(:default) && t.state_profiles.include?(:first) && t.state_profiles.include?(:second)).to be true
    expect(Target.state_profiles.include?(:default) && Target.state_profiles.include?(:first) && Target.state_profiles.include?(:second)).to be true

  end

  it 'accepts method as block' do
    
    class Target
      include Statize
      
      attr_accessor :st

      stateful initial_state: :open, state_attr_name: :st do
        event :rolling, :open => :started, &Proc.new { |pa| callback(pa) } 
      end

      def Target.callback(params)
        puts "callback #{params}" 
      end

      def initialize
        init_state
      end

    end

    t = Target.new
    t.trigger_event(:rolling)

  end

end
