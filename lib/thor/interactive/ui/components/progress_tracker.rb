# frozen_string_literal: true

class Thor
  module Interactive
    module UI
      module Components
        class ProgressTracker
          attr_reader :tasks, :current_task, :overall_progress
          
          def initialize(options = {})
            @tasks = {}
            @current_task = nil
            @overall_progress = 0
            @options = options
            @mutex = Mutex.new
            @callbacks = {
              on_start: [],
              on_progress: [],
              on_complete: [],
              on_error: []
            }
            @status_bar = options[:status_bar]
            @show_subtasks = options[:show_subtasks] != false
          end
          
          def register_task(id, name, options = {})
            @mutex.synchronize do
              @tasks[id] = {
                id: id,
                name: name,
                status: :pending,
                progress: 0,
                total: options[:total] || 100,
                subtasks: [],
                started_at: nil,
                completed_at: nil,
                error: nil,
                metadata: options[:metadata] || {}
              }
            end
          end
          
          def start_task(id)
            @mutex.synchronize do
              return unless task = @tasks[id]
              
              task[:status] = :running
              task[:started_at] = Time.now
              @current_task = id
              
              trigger_callbacks(:on_start, task)
              update_display
            end
          end
          
          def update_progress(id, progress, message = nil)
            @mutex.synchronize do
              return unless task = @tasks[id]
              
              task[:progress] = [progress, task[:total]].min
              task[:message] = message if message
              
              calculate_overall_progress
              trigger_callbacks(:on_progress, task)
              update_display
            end
          end
          
          def add_subtask(parent_id, subtask_name)
            @mutex.synchronize do
              return unless task = @tasks[parent_id]
              
              subtask_id = "#{parent_id}_sub_#{task[:subtasks].length}"
              subtask = {
                id: subtask_id,
                name: subtask_name,
                status: :pending,
                started_at: nil,
                completed_at: nil
              }
              
              task[:subtasks] << subtask
              update_display
              
              subtask_id
            end
          end
          
          def complete_subtask(parent_id, subtask_id)
            @mutex.synchronize do
              return unless task = @tasks[parent_id]
              
              if subtask = task[:subtasks].find { |s| s[:id] == subtask_id }
                subtask[:status] = :completed
                subtask[:completed_at] = Time.now
                
                # Update parent progress based on subtask completion
                completed_count = task[:subtasks].count { |s| s[:status] == :completed }
                if task[:subtasks].any?
                  subtask_progress = (completed_count.to_f / task[:subtasks].length * task[:total]).to_i
                  task[:progress] = subtask_progress
                end
                
                update_display
              end
            end
          end
          
          def complete_task(id, message = nil)
            @mutex.synchronize do
              return unless task = @tasks[id]
              
              task[:status] = :completed
              task[:progress] = task[:total]
              task[:completed_at] = Time.now
              task[:message] = message if message
              
              @current_task = nil if @current_task == id
              
              calculate_overall_progress
              trigger_callbacks(:on_complete, task)
              update_display
            end
          end
          
          def error_task(id, error_message)
            @mutex.synchronize do
              return unless task = @tasks[id]
              
              task[:status] = :error
              task[:error] = error_message
              task[:completed_at] = Time.now
              
              @current_task = nil if @current_task == id
              
              trigger_callbacks(:on_error, task)
              update_display
            end
          end
          
          def on(event, &block)
            @mutex.synchronize do
              @callbacks[event] << block if @callbacks[event]
            end
          end
          
          def with_task(name, total: 100, &block)
            id = "task_#{Time.now.to_f}"
            register_task(id, name, total: total)
            start_task(id)
            
            begin
              result = if block.arity == 1
                yield(lambda { |progress, msg| update_progress(id, progress, msg) })
              else
                yield
              end
              
              complete_task(id)
              result
            rescue => e
              error_task(id, e.message)
              raise e
            end
          end
          
          def summary
            @mutex.synchronize do
              completed = @tasks.values.count { |t| t[:status] == :completed }
              running = @tasks.values.count { |t| t[:status] == :running }
              pending = @tasks.values.count { |t| t[:status] == :pending }
              errored = @tasks.values.count { |t| t[:status] == :error }
              
              {
                total: @tasks.length,
                completed: completed,
                running: running,
                pending: pending,
                errored: errored,
                overall_progress: @overall_progress
              }
            end
          end
          
          def display_progress(style: :detailed)
            case style
            when :detailed
              display_detailed_progress
            when :simple
              display_simple_progress
            when :compact
              display_compact_progress
            else
              display_simple_progress
            end
          end
          
          private
          
          def calculate_overall_progress
            return if @tasks.empty?
            
            total_progress = @tasks.values.sum { |t| t[:progress].to_f / t[:total] * 100 }
            @overall_progress = (total_progress / @tasks.length).to_i
          end
          
          def trigger_callbacks(event, task)
            @callbacks[event].each do |callback|
              callback.call(task)
            rescue => e
              # Ignore callback errors
            end
          end
          
          def update_display
            return unless @status_bar
            
            if task = @current_task && @tasks[@current_task]
              progress_text = "#{task[:name]}: #{task[:progress]}/#{task[:total]}"
              @status_bar.set(:progress, progress_text, position: :left, color: :cyan)
            end
            
            summary_text = "Overall: #{@overall_progress}%"
            @status_bar.set(:overall, summary_text, position: :right, color: :green)
          end
          
          def display_detailed_progress
            puts "\n=== Progress Tracker ==="
            puts "Overall Progress: #{progress_bar(@overall_progress, 100)}"
            puts
            
            @tasks.each do |id, task|
              status_icon = case task[:status]
                           when :completed then "✓"
                           when :running then "⟳"
                           when :error then "✗"
                           else "○"
                           end
              
              puts "#{status_icon} #{task[:name]}"
              puts "  #{progress_bar(task[:progress], task[:total])}"
              
              if task[:message]
                puts "  #{task[:message]}"
              end
              
              if @show_subtasks && task[:subtasks].any?
                task[:subtasks].each do |subtask|
                  subtask_icon = subtask[:status] == :completed ? "✓" : "○"
                  puts "    #{subtask_icon} #{subtask[:name]}"
                end
              end
              
              if task[:status] == :error
                puts "  Error: #{task[:error]}"
              elsif task[:completed_at] && task[:started_at]
                duration = task[:completed_at] - task[:started_at]
                puts "  Duration: #{format_duration(duration)}"
              end
              
              puts
            end
          end
          
          def display_simple_progress
            running = @tasks.values.find { |t| t[:status] == :running }
            
            if running
              puts "#{running[:name]}: #{progress_bar(running[:progress], running[:total])}"
            end
            
            puts "Overall: #{progress_bar(@overall_progress, 100)} (#{summary[:completed]}/#{summary[:total]} tasks)"
          end
          
          def display_compact_progress
            stats = summary
            print "\r[#{@overall_progress}%] Tasks: #{stats[:completed]}/#{stats[:total]}"
            print " (#{stats[:running]} running)" if stats[:running] > 0
            print " (#{stats[:errored]} errors)" if stats[:errored] > 0
            $stdout.flush
          end
          
          def progress_bar(current, total, width = 30)
            return "[" + "=" * width + "]" if total == 0
            
            percentage = (current.to_f / total * 100).to_i
            filled = (current.to_f / total * width).to_i
            empty = width - filled
            
            bar = "[" + "=" * filled + " " * empty + "]"
            "#{bar} #{percentage}%"
          end
          
          def format_duration(seconds)
            if seconds < 60
              "#{seconds.round(1)}s"
            elsif seconds < 3600
              "#{(seconds / 60).to_i}m #{(seconds % 60).to_i}s"
            else
              hours = (seconds / 3600).to_i
              minutes = ((seconds % 3600) / 60).to_i
              "#{hours}h #{minutes}m"
            end
          end
        end
      end
    end
  end
end