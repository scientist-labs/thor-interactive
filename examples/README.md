# Thor Interactive Examples

## Sample Application

The `sample_app.rb` demonstrates both normal Thor CLI usage and interactive REPL mode.

### Normal CLI Usage

```bash
# Run individual commands
ruby sample_app.rb hello World
ruby sample_app.rb count
ruby sample_app.rb add "Buy groceries"
ruby sample_app.rb list
ruby sample_app.rb status
ruby sample_app.rb help
```

### Interactive REPL Mode

```bash
# Start interactive mode
ruby sample_app.rb interactive
```

Once in interactive mode:

```
sample> /hello Alice
Hello Alice!

sample> /count
Count: 1

sample> /count  
Count: 2

sample> /add First item
Added 'First item'. Total items: 1

sample> /add Second item  
Added 'Second item'. Total items: 2

sample> /list
Items:
  1. First item
  2. Second item

sample> /status
Application Status:
  Counter: 2
  Items in list: 2
  Memory usage: 15234 KB

sample> This is unrecognized text that doesn't need quotes
Echo: This is unrecognized text that doesn't need quotes

sample> What about text with "quotes" and apostrophes?
Echo: What about text with "quotes" and apostrophes?

sample> /help
Available commands (prefix with /):
  /hello               Say hello to NAME
  /count               Show and increment counter (demonstrates state persistence)
  /add                 Add item to list (demonstrates state persistence)
  /list                Show all items
  /clear               Clear all items
  /echo                Echo the text back (used as default handler)
  /status              Show application status
  /interactive         Start an interactive REPL for this application

Special commands:
  /help [COMMAND]      Show help for command
  /exit, /quit, /q     Exit the REPL

Natural language mode:
  Type anything without / to use default handler

sample> exit
Goodbye!
```

## Key Features Demonstrated

### 1. State Persistence
- The `@@counter` and `@@items` class variables maintain their state between commands in interactive mode
- In normal CLI mode, each command starts fresh

### 2. Auto-completion
- Tab completion works for command names with slash prefix
- Try typing `/h<TAB>` or `/co<TAB>` to see completions

### 3. Natural Language Mode
- Text without `/` prefix gets sent to the configured default handler
- No need to worry about quoting or escaping in natural language
- Perfect for LLM interfaces and conversational commands

### 4. Built-in Help
- `/help` shows all available commands  
- `/help COMMAND` shows help for a specific command

### 5. History
- Up/down arrows navigate command history
- History is persistent across sessions

### 6. Graceful Exit
- Ctrl+C interrupts current operation
- Ctrl+D, `exit`, `quit`, `q`, `/exit`, `/quit`, or `/q` exits the REPL

## Integration Patterns

### Minimal Integration
```ruby
class MyApp < Thor
  include Thor::Interactive::Command
  
  # Your existing Thor commands...
  desc "hello NAME", "Say hello"
  def hello(name)
    puts "Hello #{name}!"
  end
end

# Now available: ruby myapp.rb interactive
```

### Custom Configuration
```ruby
class MyApp < Thor
  include Thor::Interactive::Command
  
  configure_interactive(
    prompt: "myapp> ",
    default_handler: proc do |input, thor_instance|
      # Handle unrecognized input
      thor_instance.invoke(:search, [input])
    end
  )
  
  # Your commands...
end
```

### Programmatic Usage
```ruby
# Instead of using the mixin, start programmatically
Thor::Interactive.start(MyApp, 
  prompt: "custom> ",
  default_handler: proc { |input, instance| puts "Got: #{input}" }
)
```