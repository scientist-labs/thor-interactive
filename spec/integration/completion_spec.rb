# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "fileutils"

RSpec.describe "Path and option completion" do
  let(:app_class) do
    Class.new(Thor) do
      include Thor::Interactive::Command
      
      desc "process FILE", "Process a file"
      option :output, type: :string, aliases: "-o"
      option :verbose, type: :boolean, aliases: "-v"
      option :format, type: :string
      def process(file)
        puts "Processing #{file}"
      end
      
      desc "read FILE", "Read a file"
      def read(file)
        puts "Reading #{file}"
      end
    end
  end
  
  let(:shell) { Thor::Interactive::Shell.new(app_class) }
  
  describe "#complete_path" do
    let(:temp_dir) { Dir.mktmpdir }
    
    before do
      # Create test files in temp directory
      FileUtils.touch(File.join(temp_dir, "test_file.txt"))
      FileUtils.touch(File.join(temp_dir, "test_data.json"))
      FileUtils.touch(File.join(temp_dir, "another.rb"))
      Dir.mkdir(File.join(temp_dir, "subdir"))
      FileUtils.touch(File.join(temp_dir, "subdir", "nested.txt"))
    end
    
    after do
      FileUtils.rm_rf(temp_dir)
    end
    
    it "completes files in current directory" do
      Dir.chdir(temp_dir) do
        completions = shell.send(:complete_path, "test")
        expect(completions).to include("test_file.txt", "test_data.json")
        expect(completions).not_to include("another.rb")
      end
    end
    
    it "completes with file extensions" do
      Dir.chdir(temp_dir) do
        completions = shell.send(:complete_path, "test_file.")
        expect(completions).to include("test_file.txt")
      end
    end
    
    it "adds trailing slash for directories" do
      Dir.chdir(temp_dir) do
        completions = shell.send(:complete_path, "sub")
        expect(completions).to include("subdir/")
      end
    end
    
    it "completes files within subdirectories" do
      Dir.chdir(temp_dir) do
        completions = shell.send(:complete_path, "subdir/")
        expect(completions).to include("subdir/nested.txt")
      end
    end
    
    it "handles home directory expansion" do
      completions = shell.send(:complete_path, "~/")
      expect(completions).to be_an(Array)
      expect(completions.first).to start_with("~/") if completions.any?
    end
    
    it "handles relative paths with ./" do
      Dir.chdir(temp_dir) do
        completions = shell.send(:complete_path, "./test")
        expect(completions).to include("./test_file.txt", "./test_data.json")
      end
    end
    
    it "returns empty array for non-existent paths" do
      completions = shell.send(:complete_path, "/definitely/not/a/real/path/")
      expect(completions).to eq([])
    end
    
    it "filters out . and .. entries" do
      Dir.chdir(temp_dir) do
        completions = shell.send(:complete_path, ".")
        expect(completions).not_to include(".", "..")
      end
    end
    
    it "handles paths with spaces" do
      Dir.chdir(temp_dir) do
        # Create a file with spaces in the name
        FileUtils.touch("file with spaces.txt")
        Dir.mkdir("dir with spaces")
        
        completions = shell.send(:complete_path, "file")
        expect(completions).to include("file\\ with\\ spaces.txt")
        
        completions = shell.send(:complete_path, "dir")
        expect(completions).to include("dir\\ with\\ spaces/")
      end
    end
    
    it "shows directory contents when path ends with /" do
      Dir.chdir(temp_dir) do
        completions = shell.send(:complete_path, "subdir/")
        expect(completions).to include("subdir/nested.txt")
      end
    end
  end
  
  describe "#complete_option_names" do
    it "completes long option names" do
      task = app_class.tasks["process"]
      completions = shell.send(:complete_option_names, task, "--")
      expect(completions).to include("--output", "--verbose", "--format")
    end
    
    it "completes partial option names" do
      task = app_class.tasks["process"]
      completions = shell.send(:complete_option_names, task, "--v")
      expect(completions).to include("--verbose")
      expect(completions).not_to include("--output", "--format")
    end
    
    it "includes short aliases" do
      task = app_class.tasks["process"]
      completions = shell.send(:complete_option_names, task, "-")
      expect(completions).to include("-o", "-v")
    end
    
    it "returns empty for commands without options" do
      task = app_class.tasks["read"]
      completions = shell.send(:complete_option_names, task, "--")
      expect(completions).to eq([])
    end
    
    it "handles nil task gracefully" do
      completions = shell.send(:complete_option_names, nil, "--")
      expect(completions).to eq([])
    end
  end
  
  describe "#path_like?" do
    it "detects absolute paths" do
      expect(shell.send(:path_like?, "/usr/bin")).to be true
      expect(shell.send(:path_like?, "/home/user/file.txt")).to be true
    end
    
    it "detects home directory paths" do
      expect(shell.send(:path_like?, "~/Documents")).to be true
      expect(shell.send(:path_like?, "~/file.txt")).to be true
    end
    
    it "detects relative paths" do
      expect(shell.send(:path_like?, "./file")).to be true
      expect(shell.send(:path_like?, "../parent")).to be true
    end
    
    it "detects common file extensions" do
      expect(shell.send(:path_like?, "file.txt")).to be true
      expect(shell.send(:path_like?, "script.rb")).to be true
      expect(shell.send(:path_like?, "data.json")).to be true
      expect(shell.send(:path_like?, "doc.md")).to be true
    end
    
    it "returns false for non-path text" do
      expect(shell.send(:path_like?, "hello")).to be false
      expect(shell.send(:path_like?, "--option")).to be false
      expect(shell.send(:path_like?, "some text")).to be false
    end
  end
  
  describe "#after_path_option?" do
    it "detects common file options" do
      expect(shell.send(:after_path_option?, "/process --file ")).to be true
      expect(shell.send(:after_path_option?, "/process --output ")).to be true
      expect(shell.send(:after_path_option?, "/process --input ")).to be true
      expect(shell.send(:after_path_option?, "/process --path ")).to be true
    end
    
    it "detects short form file options" do
      expect(shell.send(:after_path_option?, "/process -f ")).to be true
      expect(shell.send(:after_path_option?, "/process -o ")).to be true
      expect(shell.send(:after_path_option?, "/process -i ")).to be true
    end
    
    it "detects directory options" do
      expect(shell.send(:after_path_option?, "/process --dir ")).to be true
      expect(shell.send(:after_path_option?, "/process --directory ")).to be true
      expect(shell.send(:after_path_option?, "/process -d ")).to be true
    end
    
    it "returns false for non-path options" do
      expect(shell.send(:after_path_option?, "/process --verbose ")).to be false
      expect(shell.send(:after_path_option?, "/process --format ")).to be false
      expect(shell.send(:after_path_option?, "/process ")).to be false
    end
  end
  
  describe "#complete_command_options" do
    it "completes paths when text looks like a path" do
      allow(shell).to receive(:complete_path).with("./file").and_return(["./file.txt"])
      
      completions = shell.send(:complete_command_options, "./file", "/process ")
      expect(completions).to eq(["./file.txt"])
    end
    
    it "completes paths after file options" do
      allow(shell).to receive(:complete_path).with("").and_return(["file1.txt", "file2.txt"])
      
      completions = shell.send(:complete_command_options, "", "/process --output ")
      expect(completions).to eq(["file1.txt", "file2.txt"])
    end
    
    it "completes option names when text starts with -" do
      completions = shell.send(:complete_command_options, "--v", "/process file.txt ")
      expect(completions).to include("--verbose")
    end
    
    it "defaults to path completion for regular text" do
      allow(shell).to receive(:complete_path).with("file").and_return(["file.txt"])
      
      completions = shell.send(:complete_command_options, "file", "/process ")
      expect(completions).to eq(["file.txt"])
    end
  end
  
  describe "integration with Reline" do
    it "provides completions through complete_input" do
      # Test command completion
      completions = shell.send(:complete_input, "proc", "/")
      expect(completions).to include("/process")
      
      # Test that natural language mode returns empty
      completions = shell.send(:complete_input, "hello", "")
      expect(completions).to eq([])
    end
    
    it "completes command arguments" do
      allow(shell).to receive(:complete_command_options).and_return(["file.txt"])
      
      completions = shell.send(:complete_input, "file", "/process ")
      expect(completions).to eq(["file.txt"])
    end
  end
end