#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "thor/interactive"

class StatusAnimationDemo < Thor
  include Thor::Interactive::Command
  
  configure_interactive(
    ui_mode: :advanced,
    animations: true,
    status_bar: true,
    prompt: "demo> "
  )
  
  desc "animations", "Show all available animation styles"
  def animations
    puts "\n=== Animation Showcase ===\n"
    
    # Spinner animations
    spinner_styles = [:dots, :dots2, :dots3, :line, :line2, :pipe, :star, 
                     :flip, :bounce, :box_bounce, :triangle, :arc, 
                     :circle, :square, :arrow]
    
    puts "Spinner Animations:"
    spinner_styles.each do |style|
      print "  #{style.to_s.ljust(15)}: "
      with_animation(type: :spinner, style: style, message: "Loading...") do
        sleep(2)
      end
      puts " ✓"
    end
    
    puts "\nProgress Animations:"
    [:bar, :dots, :blocks, :wave, :pulse].each do |style|
      print "  #{style.to_s.ljust(15)}: "
      # Note: These would need special handling in the animation engine
      puts "(demonstration)"
    end
    
    puts "\nText Animations:"
    animate_text("Typing animation demo...", type: :typing)
    animate_text("Reveal animation demo", type: :reveal)
    animate_text("Fade in animation", type: :fade_in)
    animate_text("Fade out animation", type: :fade_out)
    
    puts "\n✓ Animation showcase complete!"
  end
  
  desc "status", "Demonstrate status bar functionality"
  def status
    puts "\n=== Status Bar Demo ===\n"
    
    # Basic status updates
    set_status(:task, "Initializing...", color: :yellow)
    sleep(1)
    
    set_status(:task, "Loading data...", color: :cyan)
    set_status(:progress, "0%", position: :right, color: :green)
    sleep(1)
    
    # Simulate progress
    (1..10).each do |i|
      set_status(:task, "Processing item #{i}/10", color: :cyan)
      set_status(:progress, "#{i * 10}%", position: :right, color: :green)
      sleep(0.3)
    end
    
    set_status(:task, "✓ Complete!", color: :green)
    set_status(:progress, "100%", position: :right, color: :green)
    sleep(2)
    
    clear_status
    puts "\n✓ Status bar demo complete!"
  end
  
  desc "progress", "Demonstrate progress tracking"
  def progress
    puts "\n=== Progress Tracking Demo ===\n"
    
    # Single task with progress
    track_progress("Downloading files", total: 100) do |update|
      10.times do |i|
        update.call((i + 1) * 10, "Downloading file #{i + 1}.txt")
        sleep(0.2)
      end
    end
    
    puts "\n"
    
    # Multiple tasks
    register_task(:setup, "System setup", total: 3)
    register_task(:data, "Data processing", total: 5)
    register_task(:cleanup, "Cleanup", total: 2)
    
    start_task(:setup)
    ["Checking dependencies", "Installing packages", "Configuring system"].each_with_index do |msg, i|
      update_task_progress(:setup, i + 1, msg)
      sleep(0.5)
    end
    complete_task(:setup, "Setup complete")
    
    start_task(:data)
    5.times do |i|
      update_task_progress(:data, i + 1, "Processing batch #{i + 1}")
      sleep(0.3)
    end
    complete_task(:data)
    
    start_task(:cleanup)
    update_task_progress(:cleanup, 1, "Removing temp files")
    sleep(0.5)
    update_task_progress(:cleanup, 2, "Finalizing")
    sleep(0.5)
    complete_task(:cleanup)
    
    summary = progress_summary
    puts "\nTask Summary:"
    puts "  Total: #{summary[:total]}"
    puts "  Completed: #{summary[:completed]}"
    puts "  Overall Progress: #{summary[:overall_progress]}%"
    
    puts "\n✓ Progress tracking demo complete!"
  end
  
  desc "combined", "Combined demo with status, animation, and progress"
  def combined
    puts "\n=== Combined Features Demo ===\n"
    
    # Setup status bar
    set_status(:mode, "PROCESSING", position: :left, color: :yellow)
    set_status(:time, Time.now.strftime("%H:%M"), position: :right, color: :blue)
    
    # Task 1: Download with animation
    with_status("Downloading resources") do
      with_animation(type: :spinner, style: :dots, message: "Fetching from server") do
        sleep(2)
      end
    end
    
    # Task 2: Process with progress tracking
    with_status("Processing data") do
      track_progress("Data analysis", total: 50) do |update|
        5.times do |batch|
          10.times do |item|
            progress = batch * 10 + item + 1
            update.call(progress, "Analyzing batch #{batch + 1}, item #{item + 1}")
            sleep(0.05)
          end
        end
      end
    end
    
    # Task 3: Generate report with text animation
    set_status(:mode, "GENERATING", position: :left, color: :green)
    animate_text("\nGenerating report", type: :typing)
    
    with_animation(type: :spinner, style: :star, message: "Creating visualizations") do
      sleep(1.5)
    end
    
    # Final status
    set_status(:mode, "COMPLETE", position: :left, color: :green)
    set_status(:result, "✓ All tasks finished", position: :center, color: :green)
    sleep(2)
    
    clear_status
    puts "\n✓ Combined demo complete!"
  end
  
  desc "parallel", "Demonstrate parallel task execution with progress"
  def parallel
    puts "\n=== Parallel Tasks Demo ===\n"
    
    tasks = [
      { id: :download, name: "Download", total: 30 },
      { id: :process, name: "Process", total: 50 },
      { id: :upload, name: "Upload", total: 20 }
    ]
    
    # Register all tasks
    tasks.each do |task|
      register_task(task[:id], task[:name], total: task[:total])
    end
    
    # Simulate parallel execution
    threads = tasks.map do |task|
      Thread.new do
        start_task(task[:id])
        
        task[:total].times do |i|
          update_task_progress(task[:id], i + 1, "Step #{i + 1}/#{task[:total]}")
          sleep(rand(0.05..0.15))
        end
        
        complete_task(task[:id])
      end
    end
    
    # Wait for all to complete
    threads.each(&:join)
    
    summary = progress_summary
    puts "\nParallel Execution Complete:"
    puts "  All #{summary[:total]} tasks completed"
    puts "  Overall Progress: #{summary[:overall_progress]}%"
    
    puts "\n✓ Parallel tasks demo complete!"
  end
  
  desc "subtasks", "Demonstrate subtask management"
  def subtasks
    puts "\n=== Subtasks Demo ===\n"
    
    # Main task with subtasks
    register_task(:build, "Build Project", total: 100)
    start_task(:build)
    
    # Add and complete subtasks
    subtasks = [
      "Compile source code",
      "Run tests",
      "Generate documentation",
      "Package application",
      "Create installer"
    ]
    
    subtask_ids = subtasks.map do |name|
      progress_tracker.add_subtask(:build, name)
    end
    
    subtask_ids.each_with_index do |id, index|
      set_status(:current, subtasks[index], color: :cyan)
      
      with_animation(type: :spinner, style: :dots, message: subtasks[index]) do
        sleep(1)
      end
      
      progress_tracker.complete_subtask(:build, id)
      update_task_progress(:build, (index + 1) * 20)
    end
    
    complete_task(:build, "Build successful!")
    clear_status
    
    puts "\n✓ Subtasks demo complete!"
  end
  
  desc "error_handling", "Demonstrate error handling in progress tracking"
  def error_handling
    puts "\n=== Error Handling Demo ===\n"
    
    tasks = [:task1, :task2, :task3]
    
    tasks.each_with_index do |task_id, index|
      register_task(task_id, "Task #{index + 1}")
      start_task(task_id)
      
      begin
        if index == 1  # Simulate error on second task
          raise "Simulated error in task 2"
        end
        
        with_animation(type: :spinner, message: "Processing task #{index + 1}") do
          sleep(1)
        end
        
        complete_task(task_id)
        puts "✓ Task #{index + 1} completed"
      rescue => e
        error_task(task_id, e.message)
        puts "✗ Task #{index + 1} failed: #{e.message}"
      end
    end
    
    summary = progress_summary
    puts "\nError Handling Summary:"
    puts "  Completed: #{summary[:completed]}"
    puts "  Errors: #{summary[:errored]}"
    
    puts "\n✓ Error handling demo complete!"
  end
  
  desc "custom", "Interactive custom animation creator"
  def custom
    puts "\n=== Custom Animation Creator ===\n"
    
    print "Enter animation frames (comma-separated): "
    frames = $stdin.gets.chomp.split(',').map(&:strip)
    
    if frames.empty?
      puts "No frames provided, using default"
      frames = ["◐", "◓", "◑", "◒"]
    end
    
    print "Enter message (or press Enter for none): "
    message = $stdin.gets.chomp
    message = nil if message.empty?
    
    print "Enter duration in seconds (default 3): "
    duration = $stdin.gets.chomp.to_f
    duration = 3 if duration <= 0
    
    puts "\nRunning custom animation..."
    
    # Create custom animation
    id = "custom_#{Time.now.to_f}"
    animation_engine.start_animation(id, 
      type: :spinner, 
      style: :custom,
      options: { 
        message: message,
        interval: 0.1,
        callback: lambda do |frame_index, total_frames|
          frame = frames[frame_index % frames.length]
          print "\r#{frame} #{message}"
          $stdout.flush
        end
      }
    )
    
    sleep(duration)
    animation_engine.stop_animation(id)
    
    puts "\n✓ Custom animation complete!"
  end
  
  desc "benchmark", "Benchmark UI operations"
  def benchmark
    require 'benchmark'
    
    puts "\n=== UI Performance Benchmark ===\n"
    
    results = {}
    
    # Benchmark status bar updates
    results[:status] = ::Benchmark.realtime do
      1000.times do |i|
        set_status(:bench, "Update #{i}")
      end
    end
    clear_status
    
    # Benchmark animation frames
    results[:animation] = ::Benchmark.realtime do
      with_animation(type: :spinner, message: "Benchmarking") do
        sleep(1)
      end
    end
    
    # Benchmark progress updates
    results[:progress] = ::Benchmark.realtime do
      track_progress("Benchmark", total: 100) do |update|
        100.times { |i| update.call(i + 1) }
      end
    end
    
    puts "\nBenchmark Results:"
    puts "  Status updates (1000x): #{(results[:status] * 1000).round(2)}ms"
    puts "  Animation (1 sec): #{(results[:animation] * 1000).round(2)}ms"
    puts "  Progress updates (100x): #{(results[:progress] * 1000).round(2)}ms"
    
    puts "\n✓ Benchmark complete!"
  end
  
  default_task :help
end

if __FILE__ == $0
  # Enable UI for demo
  Thor::Interactive::UI.configure do |config|
    config.enable!
    config.animations.enabled = true
    config.status_bar.enabled = true
  end
  
  puts "Starting Status & Animation Demo..."
  puts "Run 'help' to see available commands"
  puts
  
  # Start interactive shell
  StatusAnimationDemo.new.interactive
end