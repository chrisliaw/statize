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
    }.to raise_exception(Statize::InvalidStatusForEvent)

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
    }.to raise_exception(Statize::InvalidStatusForEvent)

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


end
