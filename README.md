# Thor::Interactive

Turn any Thor CLI into an interactive terminal application with persistent state, auto-completion, and an optional rich TUI powered by [ratatui_ruby](https://www.ratatui-ruby.dev/).

Thor::Interactive converts your existing Thor command-line applications into interactive sessions — from a simple REPL to a full Claude Code-like terminal UI with multi-line input, a status bar, animated spinners, and theming. Perfect for RAG pipelines, database tools, or any CLI that benefits from persistent connections and cached state.

## Features

- **TUI Mode**: Rich terminal UI with multi-line input, status bar, spinner, tab completion overlay, and theming — powered by Rust via [ratatui_ruby](https://www.ratatui-ruby.dev/)
- **Easy Setup**: Add one line (`include Thor::Interactive::Command`) for a basic REPL, add `ratatui_ruby` to your Gemfile for the full TUI
- **State Persistence**: Maintains class variables and instance state between commands
- **Auto-completion**: Tab completion for command names, options, and paths
- **Default Handlers**: Configurable fallback for non-command input (great for natural language interfaces)
- **Command History**: Persistent history with up/down arrow navigation
- **Graceful Degradation**: TUI mode falls back to a Reline-based REPL if `ratatui_ruby` is not installed

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

# New interactive mode with slash commands
ruby myapp.rb interactive
myapp> /hello Alice
Hello Alice!
myapp> Natural language input goes to default handler
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

The key benefit is maintaining state between commands. In normal CLI mode, each invocation starts fresh. In interactive mode, a single instance persists — so expensive connections, caches, and counters survive between commands:

```ruby
class ProjectApp < Thor
  include Thor::Interactive::Command

  # These persist between commands in interactive mode
  @@db = nil
  @@tasks = []

  configure_interactive(prompt: "project> ")

  desc "connect HOST", "Connect to database"
  def connect(host)
    @@db = Database.new(host)  # Expensive — only done once
    puts "Connected to #{host}"
  end

  desc "add TASK", "Add a task"
  def add(task)
    @@tasks << {name: task, created_at: Time.now}
    puts "Added: #{task} (#{@@tasks.size} total)"
  end

  desc "list", "Show all tasks"
  def list
    @@tasks.each_with_index do |t, i|
      puts "#{i + 1}. #{t[:name]}"
    end
  end

  desc "status", "Show connection and task count"
  def status
    puts "Database: #{@@db ? 'connected' : 'not connected'}"
    puts "Tasks: #{@@tasks.size}"
  end
end
```

In interactive mode:
```bash
ruby project_app.rb interactive

project> /connect localhost
Connected to localhost

project> /add "Design API"
Added: Design API (1 total)

project> /add "Write tests"
Added: Write tests (2 total)

project> /list
1. Design API
2. Write tests

project> /status
Database: connected    # Still connected — same instance!
Tasks: 2
```

## Configuration

Configure interactive behavior:

```ruby
class MyApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    prompt: "myapp> ",                    # Custom prompt
    allow_nested: false,                  # Prevent nested sessions (default)
    nested_prompt_format: "[L%d] %s",    # Format for nested prompts (if allowed)
    default_handler: proc do |input, thor_instance|
      # Handle unrecognized input
      # IMPORTANT: Use direct method calls, NOT invoke(), to avoid Thor's
      # silent failure on repeated calls to the same method
      thor_instance.search(input)  # ✅ Works repeatedly
      # thor_instance.invoke(:search, [input])  # ❌ Fails after first call
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
myapp> /search thor interactive
Searching for: thor interactive

myapp> some random text
Searching for: some random text    # No slash needed — default handler kicks in
```

### Nested Session Management

By default, thor-interactive prevents nested interactive sessions to avoid confusion:

```ruby
class MyApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    prompt: "myapp> ",
    allow_nested: false  # Default behavior
  )
end
```

If you try to run `interactive` while already in an interactive session:

```bash
myapp> interactive
Already in an interactive session.
To allow nested sessions, configure with: configure_interactive(allow_nested: true)
```

#### Allowing Nested Sessions

For advanced use cases, you can enable nested sessions:

```ruby
class AdvancedApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    prompt: "advanced> ",
    allow_nested: true,
    nested_prompt_format: "[Level %d] %s"  # Optional custom format
  )
end
```

With nested sessions enabled:

```bash
$ ruby advanced_app.rb interactive
AdvancedApp Interactive Shell
Type 'help' for available commands, 'exit' to quit

advanced> interactive
AdvancedApp Interactive Shell (nested level 2)
Type 'exit' to return to previous level, or 'help' for commands

[Level 2] advanced> hello nested
Hello nested!

[Level 2] advanced> exit
Exiting nested session...

advanced> exit
Goodbye!
```

### ⚠️ Important: Default Handler Implementation

**Always use direct method calls in default handlers, NOT `invoke()`:**

```ruby
# ✅ CORRECT - Works for repeated calls
configure_interactive(
  default_handler: proc do |input, thor_instance|
    thor_instance.ask(input)  # Direct method call
  end
)

# ❌ WRONG - Silent failure after first call  
configure_interactive(
  default_handler: proc do |input, thor_instance|
    thor_instance.invoke(:ask, [input])  # Thor's invoke fails silently on repeat calls
  end
)
```

**Why:** Thor's `invoke` method has internal deduplication that prevents repeated calls to the same method on the same instance. This causes silent failures in interactive mode where users expect to be able to repeat commands.

## TUI Mode

For a richer terminal experience, thor-interactive supports an optional TUI mode powered by [ratatui_ruby](https://www.ratatui-ruby.dev/) — Ruby bindings for the Rust [Ratatui](https://ratatui.rs/) library.

### Setup

Add `ratatui_ruby` to your application's Gemfile:

```ruby
gem 'thor-interactive'
gem 'ratatui_ruby', '~> 1.4'  # Optional: enables TUI mode
```

Then configure your Thor app to use TUI mode:

```ruby
class MyApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    ui_mode: :tui,
    prompt: "myapp> "
  )
end
```

If `ratatui_ruby` is not installed, the app automatically falls back to the standard Reline-based REPL with a warning.

### TUI Features

- **Multi-line input**: Shift+Enter for newlines (on terminals supporting the [Kitty keyboard protocol](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)), or Ctrl+N to toggle multi-line mode on older terminals
- **Status bar**: Configurable left/center/right sections
- **Spinner**: Animated activity indicator with fun rotating messages during command execution
- **Tab completion**: Popup overlay for command and path completion
- **Scrollback**: Command output goes above the input viewport into normal terminal scrollback
- **Theming**: Predefined themes (`:default`, `:dark`, `:light`, `:minimal`) or custom colors

### Key Bindings

| Key | Action |
|-----|--------|
| Enter | Submit input |
| Shift+Enter | Insert newline (Kitty protocol terminals) |
| Ctrl+N | Toggle multi-line mode (fallback for older terminals) |
| Ctrl+J | Always submit (even in multi-line mode) |
| Tab | Auto-complete commands |
| Ctrl+C | Clear input / double-tap to exit |
| Ctrl+D | Exit |
| Escape | Clear input / exit multi-line mode |
| Up/Down | History navigation (single-line) or cursor movement (multi-line) |

### TUI Configuration

```ruby
class MyApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    ui_mode: :tui,
    prompt: "myapp> ",
    theme: :dark,                          # :default, :dark, :light, :minimal, or custom hash
    status_bar: {
      left: ->(instance) { " MyApp" },     # Left section (app name, etc.)
      right: ->(instance) { " v1.0 " }     # Right section (status info, etc.)
    },
    spinner_messages: [                     # Custom spinner messages (optional)
      "Thinking", "Brewing", "Crunching"
    ]
  )
end
```

### Custom Theme

```ruby
configure_interactive(
  ui_mode: :tui,
  theme: {
    error_fg: :light_red,
    input_border: :cyan,
    status_bar_fg: :white,
    status_bar_bg: :dark_gray
  }
)
```

See `Thor::Interactive::TUI::Theme::THEMES` for the full list of configurable color keys.

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
bundle exec rspec        # Run full test suite with coverage
bundle exec rake build   # Build gem
open coverage/index.html # View coverage report (after running tests)
```

### Testing

The gem includes comprehensive tests organized into unit and integration test suites with **72%+ code coverage**:

```bash
# Run all tests
bundle exec rspec

# Run with detailed output
bundle exec rspec --format documentation

# View coverage report
open coverage/index.html      # Detailed HTML coverage report

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

Bug reports and pull requests are welcome on GitHub at https://github.com/scientist-labs/thor-interactive.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
