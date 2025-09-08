# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Phase 3 UI Components" do
  describe Thor::Interactive::UI::Components::StatusBar do
    subject { described_class.new }
    
    describe "#set and #remove" do
      it "manages status items" do
        subject.set(:test, "Test message")
        expect(subject.items).to have_key(:test)
        expect(subject.items[:test][:value]).to eq("Test message")
        
        subject.remove(:test)
        expect(subject.items).not_to have_key(:test)
      end
      
      it "supports position and color options" do
        subject.set(:left_item, "Left", position: :left, color: :green)
        subject.set(:right_item, "Right", position: :right, color: :red)
        
        expect(subject.items[:left_item][:position]).to eq(:left)
        expect(subject.items[:left_item][:color]).to eq(:green)
        expect(subject.items[:right_item][:position]).to eq(:right)
      end
      
      it "handles priority for item ordering" do
        subject.set(:low, "Low", priority: 1)
        subject.set(:high, "High", priority: 10)
        subject.set(:medium, "Medium", priority: 5)
        
        expect(subject.items[:high][:priority]).to eq(10)
      end
    end
    
    describe "#hide and #show" do
      it "toggles visibility" do
        expect(subject.visible).to be true
        
        subject.hide
        expect(subject.visible).to be false
        
        subject.show
        expect(subject.visible).to be true
      end
    end
    
    describe "#with_hidden" do
      it "temporarily hides status bar" do
        subject.set(:test, "Test")
        expect(subject.visible).to be true
        
        result = subject.with_hidden do
          expect(subject.visible).to be false
          "result"
        end
        
        expect(result).to eq("result")
        expect(subject.visible).to be true
      end
    end
    
    describe "text truncation" do
      it "truncates long text" do
        bar = described_class.new(width: 20)
        # Test internal truncate method behavior
        expect(bar.send(:truncate, "This is a very long text that should be truncated", 10)).to eq("This is...")
      end
    end
  end
  
  describe Thor::Interactive::UI::Components::AnimationEngine do
    subject { described_class.new }
    
    describe "#start_animation and #stop_animation" do
      it "manages animation lifecycle" do
        subject.start_animation(:test, type: :spinner, style: :dots)
        expect(subject.active_animations).to have_key(:test)
        
        subject.stop_animation(:test)
        expect(subject.active_animations).not_to have_key(:test)
      end
      
      it "supports different animation types and styles" do
        subject.start_animation(:spin, type: :spinner, style: :line)
        subject.start_animation(:prog, type: :progress, style: :bar)
        
        expect(subject.active_animations[:spin][:type]).to eq(:spinner)
        expect(subject.active_animations[:spin][:style]).to eq(:line)
        expect(subject.active_animations[:prog][:type]).to eq(:progress)
        
        subject.stop_all
      end
    end
    
    describe "#with_animation" do
      it "runs block with animation" do
        result = subject.with_animation(type: :spinner, message: "Loading") do
          "completed"
        end
        
        expect(result).to eq("completed")
        expect(subject.active_animations).to be_empty
      end
      
      it "stops animation on error" do
        expect {
          subject.with_animation(type: :spinner) do
            raise "Test error"
          end
        }.to raise_error("Test error")
        
        expect(subject.active_animations).to be_empty
      end
    end
    
    describe "#update_animation" do
      it "updates animation options" do
        subject.start_animation(:test, type: :spinner, options: { message: "Initial" })
        subject.update_animation(:test, message: "Updated")
        
        expect(subject.active_animations[:test][:options][:message]).to eq("Updated")
        
        subject.stop_animation(:test)
      end
    end
    
    describe "animation styles" do
      it "has various spinner styles" do
        styles = described_class::ANIMATION_STYLES[:spinner]
        expect(styles).to include(:dots, :line, :pipe, :star, :bounce)
        expect(styles[:dots]).to be_an(Array)
      end
      
      it "has progress animation styles" do
        styles = described_class::ANIMATION_STYLES[:progress]
        expect(styles).to include(:bar, :dots, :blocks, :wave)
      end
      
      it "has text animation configurations" do
        styles = described_class::ANIMATION_STYLES[:text]
        expect(styles).to include(:typing, :reveal, :fade_in, :fade_out)
        expect(styles[:typing][:delay]).to be_a(Numeric)
      end
    end
  end
  
  describe Thor::Interactive::UI::Components::ProgressTracker do
    subject { described_class.new }
    
    describe "#register_task and task lifecycle" do
      it "registers and manages tasks" do
        subject.register_task(:task1, "First Task", total: 50)
        
        expect(subject.tasks).to have_key(:task1)
        expect(subject.tasks[:task1][:name]).to eq("First Task")
        expect(subject.tasks[:task1][:total]).to eq(50)
        expect(subject.tasks[:task1][:status]).to eq(:pending)
      end
      
      it "tracks task progress" do
        subject.register_task(:task1, "Task", total: 100)
        subject.start_task(:task1)
        
        expect(subject.tasks[:task1][:status]).to eq(:running)
        expect(subject.current_task).to eq(:task1)
        
        subject.update_progress(:task1, 50, "Half way")
        expect(subject.tasks[:task1][:progress]).to eq(50)
        expect(subject.tasks[:task1][:message]).to eq("Half way")
        
        subject.complete_task(:task1)
        expect(subject.tasks[:task1][:status]).to eq(:completed)
        expect(subject.tasks[:task1][:progress]).to eq(100)
      end
      
      it "handles task errors" do
        subject.register_task(:task1, "Task")
        subject.start_task(:task1)
        subject.error_task(:task1, "Something went wrong")
        
        expect(subject.tasks[:task1][:status]).to eq(:error)
        expect(subject.tasks[:task1][:error]).to eq("Something went wrong")
      end
    end
    
    describe "#with_task" do
      it "executes block with automatic task tracking" do
        result = subject.with_task("Processing", total: 10) do |progress|
          progress.call(5, "Half done") if progress
          "done"
        end
        
        expect(result).to eq("done")
        task = subject.tasks.values.first
        expect(task[:status]).to eq(:completed)
      end
      
      it "handles errors in with_task" do
        expect {
          subject.with_task("Failing") do
            raise "Task failed"
          end
        }.to raise_error("Task failed")
        
        task = subject.tasks.values.first
        expect(task[:status]).to eq(:error)
        expect(task[:error]).to eq("Task failed")
      end
    end
    
    describe "#add_subtask and #complete_subtask" do
      it "manages subtasks" do
        subject.register_task(:parent, "Parent Task")
        
        sub1 = subject.add_subtask(:parent, "Subtask 1")
        sub2 = subject.add_subtask(:parent, "Subtask 2")
        
        expect(subject.tasks[:parent][:subtasks].length).to eq(2)
        
        subject.complete_subtask(:parent, sub1)
        subtask = subject.tasks[:parent][:subtasks].find { |s| s[:id] == sub1 }
        expect(subtask[:status]).to eq(:completed)
      end
    end
    
    describe "#summary" do
      it "provides task summary" do
        subject.register_task(:t1, "Task 1")
        subject.register_task(:t2, "Task 2")
        subject.register_task(:t3, "Task 3")
        
        subject.start_task(:t1)
        subject.complete_task(:t2)
        subject.error_task(:t3, "Failed")
        
        summary = subject.summary
        expect(summary[:total]).to eq(3)
        expect(summary[:completed]).to eq(1)
        expect(summary[:running]).to eq(1)
        expect(summary[:errored]).to eq(1)
      end
    end
    
    describe "#on callbacks" do
      it "triggers callbacks on events" do
        started = false
        completed = false
        
        subject.on(:on_start) { started = true }
        subject.on(:on_complete) { completed = true }
        
        subject.register_task(:test, "Test")
        subject.start_task(:test)
        expect(started).to be true
        
        subject.complete_task(:test)
        expect(completed).to be true
      end
    end
    
    describe "overall progress calculation" do
      it "calculates overall progress across tasks" do
        subject.register_task(:t1, "Task 1", total: 100)
        subject.register_task(:t2, "Task 2", total: 50)
        
        subject.update_progress(:t1, 50)  # 50%
        subject.update_progress(:t2, 25)  # 50%
        
        expect(subject.overall_progress).to eq(50)
      end
    end
  end
end

RSpec.describe "Phase 3 Command Integration" do
  let(:test_app) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      configure_interactive(
        ui_mode: :advanced,
        animations: true,
        status_bar: true
      )
      
      desc "test_status", "Test status bar"
      def test_status
        set_status(:test, "Testing", color: :green)
        clear_status(:test)
      end
      
      desc "test_animation", "Test animation"
      def test_animation
        with_animation(type: :spinner, message: "Processing") do
          sleep(0.1)
        end
      end
      
      desc "test_progress", "Test progress tracking"
      def test_progress
        track_progress("Test Task", total: 10) do |update|
          update.call(5, "Half way") if update
        end
      end
    end
  end
  
  describe "status API" do
    let(:instance) { test_app.new }
    
    before do
      allow(test_app).to receive(:interactive_ui?).and_return(true)
    end
    
    it "provides status bar access" do
      expect(instance.status_bar).to be_a(Thor::Interactive::UI::Components::StatusBar)
    end
    
    it "provides animation engine access" do
      expect(instance.animation_engine).to be_a(Thor::Interactive::UI::Components::AnimationEngine)
    end
    
    it "provides progress tracker access" do
      expect(instance.progress_tracker).to be_a(Thor::Interactive::UI::Components::ProgressTracker)
    end
    
    it "gracefully handles when UI is disabled" do
      allow(test_app).to receive(:interactive_ui?).and_return(false)
      
      instance = test_app.new
      expect(instance.status_bar).to be_nil
      expect(instance.animation_engine).to be_nil
      expect(instance.progress_tracker).to be_nil
      
      # Methods should be no-ops
      expect { instance.set_status(:test, "test") }.not_to raise_error
      expect { instance.animate_text("test") }.to output("test\n").to_stdout
    end
  end
end