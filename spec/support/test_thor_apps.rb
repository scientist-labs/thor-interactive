# frozen_string_literal: true

# Test Thor applications for testing thor-interactive functionality
# These are simple, focused applications for testing specific behaviors

class SimpleTestApp < Thor
  desc "hello NAME", "Say hello to NAME"
  def hello(name)
    puts "Hello #{name}!"
  end

  desc "echo TEXT", "Echo the text back"
  def echo(*words)
    puts "Echo: #{words.join(' ')}"
  end

  desc "fail", "Always fails with an error"
  def fail
    raise StandardError, "Test error"
  end
end

class StatefulTestApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    prompt: "test> ",
    default_handler: proc do |input, instance|
      instance.invoke(:echo, [input])
    end
  )

  # Class variables to test state persistence
  class_variable_set(:@@counter, 0)
  class_variable_set(:@@items, [])

  desc "count", "Increment and show counter"
  def count
    @@counter += 1
    puts "Count: #{@@counter}"
  end

  desc "reset", "Reset counter to zero"
  def reset
    @@counter = 0
    puts "Counter reset"
  end

  desc "add ITEM", "Add item to list"
  def add(item)
    @@items << item
    puts "Added: #{item}"
  end

  desc "list", "Show all items"
  def list
    if @@items.empty?
      puts "No items"
    else
      @@items.each_with_index do |item, index|
        puts "#{index + 1}. #{item}"
      end
    end
  end

  desc "clear", "Clear all items"
  def clear
    @@items.clear
    puts "Items cleared"
  end

  desc "echo TEXT", "Echo the text (used as default handler)"
  def echo(*words)
    puts "Echo: #{words.join(' ')}"
  end

  desc "status", "Show current state"
  def status
    puts "Counter: #{@@counter}, Items: #{@@items.length}"
  end
end

class SubcommandTestApp < Thor
  desc "db SUBCOMMAND", "Database commands"
  subcommand "db", Class.new(Thor) do
    desc "create", "Create database"
    def create
      puts "Database created"
    end

    desc "drop", "Drop database"
    def drop
      puts "Database dropped"
    end
  end

  desc "server SUBCOMMAND", "Server commands"  
  subcommand "server", Class.new(Thor) do
    desc "start", "Start server"
    def start
      puts "Server started"
    end

    desc "stop", "Stop server"
    def stop
      puts "Server stopped"
    end
  end
end

class OptionsTestApp < Thor
  desc "greet NAME", "Greet someone"
  option :loud, type: :boolean, desc: "Greet loudly"
  option :times, type: :numeric, default: 1, desc: "Number of times to greet"
  def greet(name)
    greeting = "Hello #{name}!"
    greeting = greeting.upcase if options[:loud]
    
    options[:times].times do
      puts greeting
    end
  end

  desc "config KEY VALUE", "Set configuration"
  option :global, type: :boolean, desc: "Set globally"
  def config(key, value)
    scope = options[:global] ? "global" : "local"
    puts "Set #{key}=#{value} (#{scope})"
  end
end