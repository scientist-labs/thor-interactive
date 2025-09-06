#!/usr/bin/env ruby
# frozen_string_literal: true

require "thor"
require_relative "../lib/thor/interactive"

# Example Thor application that demonstrates both normal CLI usage
# and interactive REPL mode
class SampleApp < Thor
  include Thor::Interactive::Command

  # Configure interactive mode
  configure_interactive(
    prompt: "sample> ",
    default_handler: proc do |input, thor_instance|
      # Send unrecognized input to the 'echo' command
      thor_instance.invoke(:echo, [input])
    end
  )

  # Class variable to demonstrate state persistence in interactive mode
  class_variable_set(:@@counter, 0)
  class_variable_set(:@@items, [])

  desc "hello NAME", "Say hello to NAME"
  def hello(name)
    puts "Hello #{name}!"
  end

  desc "count", "Show and increment counter (demonstrates state persistence)"
  def count
    @@counter += 1
    puts "Count: #{@@counter}"
  end

  desc "add ITEM", "Add item to list (demonstrates state persistence)"
  def add(item)
    @@items << item
    puts "Added '#{item}'. Total items: #{@@items.length}"
  end

  desc "list", "Show all items"
  def list
    if @@items.empty?
      puts "No items in the list"
    else
      puts "Items:"
      @@items.each_with_index do |item, index|
        puts "  #{index + 1}. #{item}"
      end
    end
  end

  desc "clear", "Clear all items"
  def clear
    @@items.clear
    puts "List cleared"
  end

  desc "echo TEXT", "Echo the text back (used as default handler)"
  def echo(*words)
    text = words.join(" ")
    puts "Echo: #{text}"
  end

  desc "status", "Show application status"
  def status
    puts "Application Status:"
    puts "  Counter: #{@@counter}"
    puts "  Items in list: #{@@items.length}"
    puts "  Memory usage: #{`ps -o rss= -p #{Process.pid}`.strip} KB" rescue "Unknown"
  end
end

# This allows the file to work both ways:
# 1. Normal Thor CLI: ruby sample_app.rb hello World
# 2. Interactive mode: ruby sample_app.rb interactive
if __FILE__ == $0
  SampleApp.start(ARGV)
end