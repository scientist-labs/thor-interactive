# Thor::Interactive

Turn any Thor CLI into an interactive REPL with persistent state and auto-completion.

Thor::Interactive automatically converts your existing Thor command-line applications into interactive REPLs, maintaining state between commands and providing auto-completion for commands and parameters. Perfect for applications that benefit from persistent sessions like RAG pipelines, database tools, or any CLI that maintains caches or connections.

## Features

- **Zero Configuration**: Works with any existing Thor application without modifications
- **State Persistence**: Maintains class variables and instance state between commands  
- **Auto-completion**: Tab completion for command names and basic parameter support
- **Default Handlers**: Configurable fallback for non-command input
- **Command History**: Persistent readline history with up/down arrow navigation
- **Both Modes**: Supports both traditional CLI usage and interactive REPL mode
- **Graceful Exit**: Proper handling of Ctrl+C interrupts and Ctrl+D/exit commands

## Installation

Add to your application's Gemfile:

```ruby
gem 'thor-interactive'
```

Or install directly:

```bash
gem install thor-interactive
```

## Quick Start

### Option 1: Add Interactive Command (Recommended)

Add one line to your Thor class to get an `interactive` command:

```ruby
require 'thor'
require 'thor/interactive'

class MyApp < Thor
  include Thor::Interactive::Command
  
  # Your existing Thor commands work unchanged
  desc "hello NAME", "Say hello"
  def hello(name)
    puts "Hello #{name}!"
  end
end
```

Now your app supports both modes:

```bash
# Normal CLI usage (unchanged)
ruby myapp.rb hello World

# New interactive mode  
ruby myapp.rb interactive
myapp> hello Alice
Hello Alice!
myapp> exit
```

### Option 2: Programmatic Usage

Start an interactive shell programmatically:

```ruby
require 'thor/interactive'

class MyApp < Thor
  desc "hello NAME", "Say hello"
  def hello(name)
    puts "Hello #{name}!"
  end
end

# Start interactive shell
Thor::Interactive.start(MyApp)
```

## State Persistence Example

The key benefit is maintaining state between commands:

```ruby
class RAGApp < Thor
  include Thor::Interactive::Command
  
  # These persist between commands in interactive mode
  class_variable_set(:@@llm_client, nil)  
  class_variable_set(:@@conversation_history, [])
  
  desc "ask TEXT", "Ask the LLM a question"
  def ask(text)
    # Initialize once, reuse across commands
    @@llm_client ||= expensive_llm_initialization
    
    response = @@llm_client.chat(text)
    @@conversation_history << {input: text, output: response}
    puts response
  end
  
  desc "history", "Show conversation history"
  def history
    @@conversation_history.each_with_index do |item, i|
      puts "#{i+1}. Q: #{item[:input]}"
      puts "   A: #{item[:output]}"
    end
  end
end
```

In interactive mode:
```bash
ruby rag_app.rb interactive

rag> ask "What is Ruby?"
# LLM initializes once
Ruby is a programming language...

rag> ask "Tell me more" 
# LLM client reused, conversation context maintained
Based on our previous discussion about Ruby...

rag> history
1. Q: What is Ruby?
   A: Ruby is a programming language...
2. Q: Tell me more
   A: Based on our previous discussion about Ruby...
```

## Configuration

Configure interactive behavior:

```ruby
class MyApp < Thor
  include Thor::Interactive::Command
  
  configure_interactive(
    prompt: "myapp> ",                    # Custom prompt
    default_handler: proc do |input, thor_instance|
      # Handle unrecognized input
      thor_instance.invoke(:search, [input])
    end
  )
  
  desc "search QUERY", "Search for something"
  def search(query)
    puts "Searching for: #{query}"
  end
end
```

Now unrecognized input gets sent to the search command:

```bash
myapp> hello world
Hello world!

myapp> some random text
Searching for: some random text
```

## Advanced Usage

### Custom Options

Pass options to the interactive command:

```bash
ruby myapp.rb interactive --prompt="custom> " --history-file=~/.my_history
```

### Multiple Applications

Use the same gem with different Thor applications:

```ruby
# Database CLI
class DBApp < Thor
  include Thor::Interactive::Command
  configure_interactive(prompt: "db> ")
end

# API Testing CLI  
class APIApp < Thor
  include Thor::Interactive::Command
  configure_interactive(prompt: "api> ")
end
```

### Without Mixin

Use programmatically without including the module:

```ruby
default_handler = proc do |input, instance|
  puts "You said: #{input}"
end

Thor::Interactive.start(MyThorApp,
  prompt: "custom> ",
  default_handler: default_handler,
  history_file: "~/.custom_history"
)
```

## Examples

See the `examples/` directory for complete working examples:

- `sample_app.rb` - Demonstrates all features with a simple CLI
- `test_interactive.rb` - Test script showing the API

Run the example:

```bash
cd examples
ruby sample_app.rb interactive
```

## How It Works

Thor::Interactive creates a persistent instance of your Thor class and invokes commands on that same instance, preserving any instance variables or class variables between commands. This is different from normal CLI usage where each command starts with a fresh instance.

The shell provides:
- Tab completion for command names
- Readline history with persistent storage  
- Proper signal handling (Ctrl+C, Ctrl+D)
- Help system integration
- Configurable default handlers for non-commands

## Development

### Getting Started

After checking out the repo:

```bash
bundle install           # Install dependencies
bundle exec rspec        # Run full test suite
bundle exec rake build   # Build gem
```

### Testing

The gem includes comprehensive tests organized into unit and integration test suites:

```bash
# Run all tests
bundle exec rspec

# Run with detailed output
bundle exec rspec --format documentation

# Run specific test suites
bundle exec rspec spec/unit/           # Unit tests only
bundle exec rspec spec/integration/    # Integration tests only

# Run specific test files
bundle exec rspec spec/unit/shell_spec.rb
bundle exec rspec spec/integration/shell_integration_spec.rb
```

#### Test Structure

```
spec/
├── spec_helper.rb              # Test configuration and shared setup
├── support/
│   ├── test_thor_apps.rb       # Test Thor applications (not packaged)
│   └── capture_helpers.rb      # Test utilities for I/O capture
├── unit/                       # Unit tests for individual components
│   ├── shell_spec.rb           # Thor::Interactive::Shell tests
│   ├── command_spec.rb         # Thor::Interactive::Command mixin tests
│   └── completion_spec.rb      # Completion system tests
└── integration/                # Integration tests for full workflows
    └── shell_integration_spec.rb # End-to-end interactive shell tests
```

#### Test Applications

Tests use dedicated Thor applications in `spec/support/test_thor_apps.rb`:

- `SimpleTestApp` - Basic Thor app with simple commands
- `StatefulTestApp` - App with state persistence and default handlers  
- `SubcommandTestApp` - App with Thor subcommands
- `OptionsTestApp` - App with various Thor options and arguments

These test apps are excluded from the packaged gem but provide comprehensive test coverage.

### Example Applications

The `examples/` directory contains working examples (these ARE packaged with the gem):

#### Running the Sample Application

```bash
cd examples

# Run in normal CLI mode
ruby sample_app.rb help
ruby sample_app.rb hello World
ruby sample_app.rb count
ruby sample_app.rb add "Test item"

# Run in interactive mode
ruby sample_app.rb interactive
```

#### Interactive Session Example

```bash
$ ruby sample_app.rb interactive
SampleApp Interactive Shell
Type 'help' for available commands, 'exit' to quit

sample> hello Alice
Hello Alice!

sample> count
Count: 1

sample> count  
Count: 2    # Note: state persisted!

sample> add "Buy groceries"
Added: Buy groceries

sample> add "Walk the dog"
Added: Walk the dog

sample> list
1. Buy groceries
2. Walk the dog

sample> status
Counter: 2, Items: 2

sample> This is random text that doesn't match a command
Echo: This is random text that doesn't match a command

sample> help
Available commands:
  hello                Say hello to NAME
  count                Show and increment counter (demonstrates state persistence)
  add                  Add item to list (demonstrates state persistence)
  list                 Show all items
  clear                Clear all items
  echo                 Echo the text back (used as default handler)
  status               Show application status
  interactive          Start an interactive REPL for this application

Special commands:
  help [COMMAND]       Show help for command
  exit/quit/q          Exit the REPL

sample> exit
Goodbye!
```

#### Key Features Demonstrated

1. **State Persistence**: The counter and items list maintain their values between commands
2. **Auto-completion**: Try typing `h<TAB>` or `co<TAB>` to see command completion
3. **Default Handler**: Text that doesn't match a command gets sent to the `echo` command
4. **Command History**: Use up/down arrows to navigate previous commands
5. **Error Handling**: Try invalid commands or missing arguments
6. **Both Modes**: The same application works as traditional CLI and interactive REPL

### Performance Testing

For applications with expensive initialization (like LLM clients), you can measure the performance benefit:

```bash
# CLI mode - initializes fresh each time
time ruby sample_app.rb count
time ruby sample_app.rb count
time ruby sample_app.rb count

# Interactive mode - initializes once, reuses state
ruby sample_app.rb interactive
# Then run: count, count, count
```

### Debugging

Enable debug mode to see backtraces on errors:

```bash
DEBUG=1 ruby sample_app.rb interactive
```

Or in your application:

```ruby
ENV["DEBUG"] = "1"
Thor::Interactive.start(MyApp)
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/cpetersen/thor-interactive.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).