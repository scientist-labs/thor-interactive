<img src="/docs/assets/thor-interactive-wide.png" alt="thor-interactive" height="80px">

Turn any Thor CLI into an interactive terminal application with persistent state, auto-completion, and a rich TUI powered by [ratatui_ruby](https://www.ratatui-ruby.dev/).

<img src="/docs/assets/screenshot.png" alt="thor-interactive TUI screenshot" width="600">
<br><sub>Screenshot from <a href="https://github.com/scientist-labs/ragnar-cli">Ragnar</a>, a RAG pipeline built with thor-interactive.</sub>

Thor::Interactive converts your existing Thor command-line applications into interactive sessions — a Claude Code-like terminal UI with multi-line input, a status bar, animated spinners, and theming. Perfect for RAG pipelines, database tools, or any CLI that benefits from persistent connections and cached state.

## Features

- **TUI Mode**: Rich terminal UI with multi-line input, status bar, spinner, tab completion overlay, and theming — powered by Rust via [ratatui_ruby](https://www.ratatui-ruby.dev/)
- **State Persistence**: Maintains class variables and instance state between commands
- **Auto-completion**: Tab completion for command names, options, and paths
- **Default Handlers**: Configurable fallback for non-command input (great for natural language interfaces)
- **Command History**: Persistent history with up/down arrow navigation
- **Graceful Degradation**: Falls back to a Reline-based REPL if `ratatui_ruby` is not installed

## Quick Start

### Installation

Add to your application's Gemfile:

```ruby
gem 'thor-interactive'
gem 'ratatui_ruby', '~> 1.4'  # Enables TUI mode
```

### Basic Usage

```ruby
require 'thor'
require 'thor/interactive'

class MyApp < Thor
  include Thor::Interactive::Command

  configure_interactive(
    ui_mode: :tui,
    prompt: "myapp> "
  )

  desc "hello NAME", "Say hello"
  def hello(name)
    puts "Hello #{name}!"
  end

  desc "search QUERY", "Search for something"
  def search(query)
    puts "Searching for: #{query}"
  end
end

MyApp.start(ARGV)
```

Then `bundle install` and run:

```bash
# Normal CLI usage (unchanged)
bundle exec ruby myapp.rb hello World

# Interactive TUI mode
bundle exec ruby myapp.rb interactive
```

> **Note:** `bundle exec` ensures `ratatui_ruby` is loaded. Without it, you'll get the basic Reline REPL instead of the TUI.

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

## State Persistence

The key benefit of interactive mode is maintaining state between commands. In normal CLI mode, each invocation starts fresh. In interactive mode, a single instance persists — so expensive connections, caches, and counters survive between commands:

```ruby
class ProjectApp < Thor
  include Thor::Interactive::Command

  @@db = nil
  @@tasks = []

  configure_interactive(
    ui_mode: :tui,
    prompt: "project> "
  )

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

```bash
project> /connect localhost
Connected to localhost

project> /add "Design API"
Added: Design API (1 total)

project> /add "Write tests"
Added: Write tests (2 total)

project> /status
Database: connected    # Still connected — same instance!
Tasks: 2
```

## Configuration

### TUI Options

```ruby
configure_interactive(
  ui_mode: :tui,
  prompt: "myapp> ",
  theme: :dark,                          # :default, :dark, :light, :minimal, or custom hash
  status_bar: {
    left: ->(instance) { " MyApp" },     # Left section
    right: ->(instance) { " v1.0 " }     # Right section
  },
  spinner_messages: [                     # Custom spinner messages (optional)
    "Thinking", "Brewing", "Crunching"
  ]
)
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

### Default Handlers

Route unrecognized input to a command automatically:

```ruby
configure_interactive(
  ui_mode: :tui,
  prompt: "myapp> ",
  default_handler: proc do |input, thor_instance|
    thor_instance.search(input)
  end
)
```

```bash
myapp> /search thor interactive
Searching for: thor interactive

myapp> some random text
Searching for: some random text    # No slash needed — default handler kicks in
```

**Important:** Always use direct method calls in default handlers, not `invoke()`. Thor's `invoke` has internal deduplication that silently prevents repeated calls to the same method.

### All Options

```ruby
configure_interactive(
  ui_mode: :tui,                         # :tui for TUI mode (omit for basic REPL)
  prompt: "myapp> ",                     # Custom prompt
  theme: :dark,                          # TUI theme
  status_bar: { left: ..., right: ... }, # TUI status bar sections
  spinner_messages: [...],               # TUI spinner messages
  history_file: "~/.myapp_history",      # Custom history file location
  allow_nested: false,                   # Prevent nested sessions (default)
  default_handler: proc { |input, i| },  # Handle non-command input
  ctrl_c_behavior: :clear_prompt,        # :clear_prompt, :show_help, or :silent
  double_ctrl_c_timeout: 0.5            # Seconds for double Ctrl+C exit
)
```

## Basic REPL Mode (without ratatui_ruby)

If you don't need the TUI, or `ratatui_ruby` isn't available, thor-interactive provides a Reline-based REPL. Just omit `ui_mode: :tui`:

```ruby
class MyApp < Thor
  include Thor::Interactive::Command

  configure_interactive(prompt: "myapp> ")

  desc "hello NAME", "Say hello"
  def hello(name)
    puts "Hello #{name}!"
  end
end
```

Or start programmatically:

```ruby
Thor::Interactive.start(MyApp, prompt: "custom> ")
```

## Development

```bash
bundle install           # Install dependencies
bundle exec rspec        # Run tests (446 examples)
bundle exec rake build   # Build gem
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/scientist-labs/thor-interactive.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
