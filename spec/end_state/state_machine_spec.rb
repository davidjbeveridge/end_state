require 'spec_helper'
require 'ostruct'

module EndState
  describe StateMachine do
    subject(:machine) { StateMachine.new(object) }
    let(:object) { OpenStruct.new(state: nil) }
    before { StateMachine.instance_variable_set '@transitions'.to_sym, nil }

    describe '.transition' do
      let(:state_map) { { a: :b } }
      let(:yielded) { OpenStruct.new(transition: nil) }
      before { StateMachine.transition(state_map) { |transition| yielded.transition = transition } }

      it 'yields a transition for the supplied end state' do
        expect(yielded.transition.state).to eq :b
      end

      it 'does not require a block' do
        expect(StateMachine.transition(b: :c)).not_to raise_error
      end

      it 'adds the transition to the state machine' do
        expect(StateMachine.transitions[state_map]).to eq yielded.transition
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

    describe '#state' do
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

        specify { expect(machine.a?).to be_true }
        specify { expect(machine.b?).to be_false }
      end

      context 'when the object has state :b' do
        let(:object) { OpenStruct.new(state: :b) }

        specify { expect(machine.b?).to be_true }
        specify { expect(machine.a?).to be_false }
      end
    end

    describe '#{state}!' do
      let(:object) { OpenStruct.new(state: :a) }
      before do
        StateMachine.transition a: :b
      end

      it 'transitions the state' do
        machine.b!
        expect(machine.state).to eq :b
      end
    end

    describe '#can_transition?' do
      let(:object) { OpenStruct.new(state: :a) }
      before do
        StateMachine.transition a: :b
        StateMachine.transition b: :c
      end

      context 'when asking about an allowed transition' do
        specify { expect(machine.can_transition? :b).to be_true }
      end

      context 'when asking about a disallowed transition' do
        specify { expect(machine.can_transition? :c).to be_false }
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
            expect(machine.transition(:b)).to be_false
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
        end

        context 'and a guard is configured' do
          let(:guard) { double :guard, new: guard_instance }
          let(:guard_instance) { double :guard_instance, allowed?: nil }
          before do
            StateMachine.transition a: :b
            StateMachine.transitions[{ a: :b }].guards << { guard: guard, params: {} }
          end

          context 'and the object satisfies the guard' do
            before do
              guard_instance.stub(:allowed?).and_return(true)
              object.state = :a
            end

            it 'transitions the state' do
              machine.transition :b
              expect(object.state).to eq :b
            end
          end

          context 'and the object does not satisfy the guard' do
            before do
              guard_instance.stub(:allowed?).and_return(false)
              object.state = :a
            end

            it 'does not transition the state' do
              machine.transition :b
              expect(object.state).to eq :a
            end
          end
        end

        context 'and a finalizer is configured' do
          before do
            StateMachine.transition a: :b do |transition|
              transition.persistence_on
            end
          end

          context 'and the finalizer is successful' do
            before do
              object.state = :a
              object.stub(:save).and_return(true)
            end

            it 'transitions the state' do
              machine.transition :b
              expect(object.state).to eq :b
            end
          end

          context 'and the finalizer fails' do
            before do
              object.state = :a
              object.stub(:save).and_return(false)
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
            expect { machine.transition!(:b) }.to raise_error(UnknownTransition)
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
            StateMachine.transitions[{ a: :b }].guards << { guard: guard, params: {} }
          end

          context 'and the object satisfies the guard' do
            before do
              guard_instance.stub(:allowed?).and_return(true)
              object.state = :a
            end

            it 'transitions the state' do
              machine.transition! :b
              expect(object.state).to eq :b
            end
          end

          context 'and the object does not satisfy the guard' do
            before do
              guard_instance.stub(:allowed?).and_return(false)
              object.state = :a
            end

            it 'does not transition the state' do
              expect { machine.transition! :b }.to raise_error(GuardFailed)
              expect(object.state).to eq :a
            end
          end
        end

        context 'and a finalizer is configured' do
          before do
            StateMachine.transition a: :b do |transition|
              transition.persistence_on
            end
          end

          context 'and the finalizer is successful' do
            before do
              object.state = :a
              object.stub(:save).and_return(true)
            end

            it 'transitions the state' do
              machine.transition! :b
              expect(object.state).to eq :b
            end
          end

          context 'and the finalizer fails' do
            before do
              object.state = :a
              object.stub(:save).and_return(false)
            end

            it 'does not transition the state' do
              expect { machine.transition! :b }.to raise_error(FinalizerFailed)
              expect(object.state).to eq :a
            end
          end
        end
      end
    end
  end
end