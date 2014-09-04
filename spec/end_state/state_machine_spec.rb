require 'spec_helper'
require 'ostruct'

module EndState
  describe StateMachine do
    subject(:machine) { StateMachine.new(object) }
    let(:object) { OpenStruct.new(state: nil) }
    before do
      StateMachine.instance_variable_set '@transitions'.to_sym, nil
      StateMachine.instance_variable_set '@events'.to_sym, nil
      StateMachine.instance_variable_set '@store_states_as_strings'.to_sym, nil
      StateMachine.instance_variable_set '@initial_state'.to_sym, :__nil__
      StateMachine.instance_variable_set '@mode'.to_sym, :soft
    end

    describe '.transition' do
      let(:options) { { a: :b } }

      before do
        @transitions = []
        StateMachine.transition(options) { |transition| @transitions << transition }
      end

      it 'does not require a block' do
        expect { StateMachine.transition(options) }.not_to raise_error
      end

      context 'single transition' do
        it 'yields a transition for the supplied end state' do
          expect(@transitions.count).to eq 1
          expect(@transitions[0].state).to eq :b
        end

        it 'adds the transition to the state machine' do
          expect(StateMachine.transitions[a: :b]).to eq @transitions[0]
        end

        context 'with as' do
          let(:options) { { a: :b, as: :go } }

          it 'creates an alias' do
            expect(StateMachine.events[:go]).to eq [{ a: :b }]
          end

          context 'another single transition with as' do
            before { StateMachine.transition({c: :d, as: :go}) }

            it 'appends to the event' do
              expect(StateMachine.events[:go]).to eq [{ a: :b }, { c: :d }]
            end
          end
        end
      end

      context 'multiple start states' do
        let(:options) { { [:a, :b] => :c } }

        it 'yields each transition for the supplied end state' do
          expect(@transitions.count).to eq 1
          expect(@transitions[0].state).to eq :c
        end

        it 'adds the transitions to the state machine' do
          expect(StateMachine.transitions[a: :c]).to eq @transitions[0]
          expect(StateMachine.transitions[b: :c]).to eq @transitions[0]
        end

        context 'with as' do
          let(:options) { { [:a, :b] => :c, as: :go } }

          it 'creates an alias' do
            expect(StateMachine.events[:go]).to eq [{ a: :c }, { b: :c }]
          end
        end
      end

      context 'multiple transitions' do
        let(:options) { { a: :b, c: :d } }

        it 'yields each transition for the supplied end state' do
          expect(@transitions.count).to eq 2
          expect(@transitions[0].state).to eq :b
          expect(@transitions[1].state).to eq :d
        end

        it 'adds the transitions to the state machine' do
          expect(StateMachine.transitions[a: :b]).to eq @transitions[0]
          expect(StateMachine.transitions[c: :d]).to eq @transitions[1]
        end

        context 'with as' do
          let(:options) { { a: :b, c: :d, as: :go } }

          it 'creates an alias' do
            expect(StateMachine.events[:go]).to eq [{ a: :b }, { c: :d }]
          end
        end
      end
    end

    describe '.state_attribute' do
      context 'when set to :foobar' do
        let(:object) { OpenStruct.new(foobar: :a) }
        before { StateMachine.state_attribute :foobar }

        it 'answers state with foobar' do
          expect(machine.state).to eq object.foobar
        end

        it 'answers state= with foobar=' do
          machine.state = :b
          expect(object.foobar).to eq :b
        end

        after do
          StateMachine.send(:remove_method, :state)
          StateMachine.send(:remove_method, :state=)
        end
      end
    end

    describe '.states' do
      before do
        StateMachine.transition(a: :b)
        StateMachine.transition(b: :c)
      end

      specify { expect(StateMachine.states).to eq [:a, :b, :c] }
    end

    describe '.start_states' do
      before do
        StateMachine.transition(a: :b)
        StateMachine.transition(b: :c)
      end

      specify { expect(StateMachine.start_states).to eq [:a, :b] }
    end

    describe '.end_states' do
      before do
        StateMachine.transition(a: :b)
        StateMachine.transition(b: :c)
      end

      specify { expect(StateMachine.end_states).to eq [:b, :c] }
    end

    describe '.store_states_as_strings!' do
      it 'sets the flag' do
        StateMachine.store_states_as_strings!
        expect(StateMachine.store_states_as_strings).to be true
      end
    end

    describe '#store_states_as_strings' do
      it 'is false by default' do
        expect(StateMachine.store_states_as_strings).to be false
      end
    end

    describe '.initial_state' do
      context 'when set to :first' do
        before { StateMachine.set_initial_state :first }

        it 'has that initial state' do
          expect(machine.state).to eq :first
        end
      end
    end

    describe '#state' do
      context 'when there is no state set' do
        specify { expect(machine.state).to eq :__nil__ }
      end

      context 'when the object has state :a' do
        let(:object) { OpenStruct.new(state: :a) }

        specify { expect(machine.state).to eq :a }
      end

      context 'when the object has state :b' do
        let(:object) { OpenStruct.new(state: :b) }

        specify { expect(machine.state).to eq :b }
      end
    end

    describe '#{state}?' do
      before do
        StateMachine.transition a: :b
        StateMachine.transition b: :c
      end

      context 'when the object has state :a' do
        let(:object) { OpenStruct.new(state: :a) }

        specify { expect(machine.a?).to be true }
        specify { expect(machine.b?).to be false }
      end

      context 'when the object has state :b' do
        let(:object) { OpenStruct.new(state: :b) }

        specify { expect(machine.b?).to be true }
        specify { expect(machine.a?).to be false }
      end

      context 'when the state shares a name with an event' do
        before { StateMachine.transition start: :stop, as: :stop }

        context 'and the object, in that state, cannot transition on the event' do
          let(:object) { OpenStruct.new(state: :stop) }

          specify { expect(machine.stop?).to be true }
        end
      end

      context 'when the requested predicate is not a state or event' do
        module Predicate
          def foo? ; :foo ; end
        end

        before { object.extend(Predicate) }

        it 'call super up to SimpleDelegator, which handles the method' do
          expect(machine.foo?).to eq(:foo)
        end
      end
    end

    describe '#{event}' do
      let(:object) { OpenStruct.new(state: :a) }
      before do
        StateMachine.transition a: :b, as: :go do |t|
          t.blocked 'Invalid event!'
        end
      end

      it 'transitions the state' do
        machine.go
        expect(machine.state).to eq :b
      end

      it 'accepts params' do
        allow(machine).to receive(:transition)
        machine.go foo: 'bar', bar: 'foo'
        expect(machine).to have_received(:transition).with(:b, { foo: 'bar', bar: 'foo' }, :soft)
      end

      it 'defaults params to {}' do
        allow(machine).to receive(:transition)
        machine.go
        expect(machine).to have_received(:transition).with(:b, {}, :soft)
      end

      context 'when the intial state is :c' do
        let(:object) { OpenStruct.new(state: :c) }

        it 'blocks invalid events' do
          machine.go
          expect(machine.state).to eq :c
        end

        it 'adds a failure message specified by blocked' do
          machine.go
          expect(machine.failure_messages).to eq ['Invalid event!']
        end

        context 'and all transitions are forced to run in :hard mode' do
          before { machine.class.treat_all_transitions_as_hard! }

          it 'raises an InvalidTransition error' do
            expect { machine.go }.to raise_error(InvalidTransition)
          end
        end
      end

      context 'when using any_state with an event' do
        before do
          StateMachine.transition any_state: :end, as: :jump_to_end
        end

        it 'transitions the state to :end' do
          machine.jump_to_end
          expect(machine.state).to eq :end
        end
      end
    end

    describe '#{event}!' do
      let(:object) { OpenStruct.new(state: :a) }
      before do
        StateMachine.transition a: :b, as: :go do |t|
          t.blocked 'Invalid event!'
        end
      end

      it 'transitions the state' do
        machine.go!
        expect(machine.state).to eq :b
      end

      it 'accepts params' do
        allow(machine).to receive(:transition)
        machine.go! foo: 'bar', bar: 'foo'
        expect(machine).to have_received(:transition).with(:b, { foo: 'bar', bar: 'foo' }, :hard)
      end

      it 'defaults params to {}' do
        allow(machine).to receive(:transition)
        machine.go!
        expect(machine).to have_received(:transition).with(:b, {}, :hard)
      end

      context 'when the intial state is :c' do
        let(:object) { OpenStruct.new(state: :c) }

        it 'blocks invalid events' do
          expect { machine.go! }.to raise_error
          expect(machine.state).to eq :c
        end
      end

      context 'when using any_state with an event' do
        before do
          StateMachine.transition any_state: :end, as: :jump_to_end
        end

        it 'transitions the state to :end' do
          machine.jump_to_end!
          expect(machine.state).to eq :end
        end
      end
    end

    describe '#can_transition?' do
      let(:object) { OpenStruct.new(state: :a) }
      before do
        StateMachine.transition a: :b
        StateMachine.transition b: :c
      end

      context 'when asking about an allowed transition' do
        specify { expect(machine.can_transition? :b).to be true }
      end

      context 'when asking about a disallowed transition' do
        specify { expect(machine.can_transition? :c).to be false }
      end

      context 'when using :any_state' do
        before { StateMachine.transition any_state: :d }

        context 'and the initial state is :a' do
          let(:object) { OpenStruct.new(state: :a) }

          specify { expect(machine.can_transition? :d).to be true }
        end

        context 'and the initial state is :b' do
          let(:object) { OpenStruct.new(state: :b) }

          specify { expect(machine.can_transition? :d).to be true }
        end
      end
    end

    describe '#transition' do
      context 'when the transition does not exist' do
        it 'raises an unknown state error' do
          expect { machine.transition(:no_state) }.to raise_error(UnknownState)
        end

        context 'but the attempted state does exist' do
          before { StateMachine.transition a: :b }

          it 'returns false' do
            expect(machine.transition(:b)).to be false
          end
        end
      end

      context 'when the transition does exist' do
        before { object.state = :a }

        context 'and no configuration is given' do
          before { StateMachine.transition a: :b }

          it 'transitions the state' do
            machine.transition :b
            expect(object.state).to eq :b
          end

          context 'and the machine is set to store_states_as_strings' do
            before { StateMachine.store_states_as_strings! }

            it 'transitions the state stored as a string' do
              machine.transition :b
              expect(object.state).to eq 'b'
            end
          end

          context 'and using :any_state' do
            before { StateMachine.transition any_state: :d }

            context 'and the initial state is :a' do
              before { object.state = :a }

              it 'transitions the state' do
                machine.transition :d
                expect(object.state).to eq :d
              end
            end

            context 'and the initial state is :b' do
              before { object.state = :b }

              it 'transitions the state' do
                machine.transition :d
                expect(object.state).to eq :d
              end
            end
          end
        end

        context 'and a guard is configured' do
          let(:guard) { double :guard, new: guard_instance }
          let(:guard_instance) { double :guard_instance, allowed?: nil }
          before do
            StateMachine.transition a: :b do |transition|
              transition.guard guard
            end
          end

          context 'and the object satisfies the guard' do
            before do
              allow(guard_instance).to receive(:allowed?).and_return(true)
              object.state = :a
            end

            it 'transitions the state' do
              machine.transition :b
              expect(object.state).to eq :b
            end
          end

          context 'and the object does not satisfy the guard' do
            before do
              allow(guard_instance).to receive(:allowed?).and_return(false)
              object.state = :a
            end

            it 'does not transition the state' do
              machine.transition :b
              expect(object.state).to eq :a
            end
          end

          context 'and params are passed in' do
            let(:params) { { foo: 'bar' } }
            it 'sends the guard the params' do
              machine.transition :b, params, :soft
              expect(guard).to have_received(:new).with(machine, :b, params)
            end
          end
        end

        context 'and a concluder is configured' do
          let(:concluder) { double :concluder, new: concluder_instance }
          let(:concluder_instance) { double :concluder_instance, call: nil, rollback: nil }
          before do
            StateMachine.transition a: :b do |transition|
              transition.concluder concluder
            end
          end

          context 'and the concluder is successful' do
            before do
              allow(concluder_instance).to receive(:call).and_return(true)
            end

            it 'transitions the state' do
              machine.transition :b
              expect(object.state).to eq :b
            end
          end

          context 'and the concluder fails' do
            before do
              allow(concluder_instance).to receive(:call).and_return(false)
            end

            it 'does not transition the state' do
              machine.transition :b
              expect(object.state).to eq :a
            end
          end
        end
      end
    end

    describe '#transition!' do
      context 'when the transition does not exist' do
        it 'raises an unknown state error' do
          expect { machine.transition!(:no_state) }.to raise_error(UnknownState)
        end

        context 'but the attempted state does exist' do
          before { StateMachine.transition a: :b }

          it 'returns false' do
            expect { machine.transition!(:b) }.to raise_error(InvalidTransition)
          end
        end
      end

      context 'when the transition does exist' do
        before { object.state = :a }

        context 'and no configuration is given' do
          before { StateMachine.transition a: :b }

          it 'transitions the state' do
            machine.transition! :b
            expect(object.state).to eq :b
          end
        end

        context 'and a guard is configured' do
          let(:guard) { double :guard, new: guard_instance }
          let(:guard_instance) { double :guard_instance, allowed?: nil }
          before do
            StateMachine.transition a: :b
            StateMachine.transitions[{ a: :b }].guards << guard
          end

          context 'and the object satisfies the guard' do
            before do
              allow(guard_instance).to receive(:allowed?).and_return(true)
              object.state = :a
            end

            it 'transitions the state' do
              machine.transition! :b
              expect(object.state).to eq :b
            end
          end

          context 'and the object does not satisfy the guard' do
            before do
              allow(guard_instance).to receive(:allowed?).and_return(false)
              object.state = :a
            end

            it 'does not transition the state' do
              expect { machine.transition! :b }.to raise_error(GuardFailed)
              expect(object.state).to eq :a
            end
          end
        end

        context 'and a concluder is configured' do
          let(:concluder) { double :concluder, new: concluder_instance }
          let(:concluder_instance) { double :concluder_instance, call: nil, rollback: nil }
          before do
            StateMachine.transition a: :b do |transition|
              transition.concluder concluder
            end
          end

          context 'and the concluder is successful' do
            before do
              allow(concluder_instance).to receive(:call).and_return(true)
            end

            it 'transitions the state' do
              machine.transition! :b
              expect(object.state).to eq :b
            end
          end

          context 'and the concluder fails' do
            before do
              allow(concluder_instance).to receive(:call).and_return(false)
            end

            it 'does not transition the state' do
              expect { machine.transition! :b }.to raise_error(ConcluderFailed)
              expect(object.state).to eq :a
            end
          end
        end
      end
    end
  end
end
