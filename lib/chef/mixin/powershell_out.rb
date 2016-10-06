#--
# Copyright:: Copyright 2015-2016, Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "chef/mixin/shell_out"
require "chef/mixin/windows_architecture_helper"

class Chef
  module Mixin
    module PowershellOut
      include Chef::Mixin::ShellOut
      include Chef::Mixin::WindowsArchitectureHelper

      # Run a command under powershell with the same API as shell_out.  The
      # options hash is extended to take an "architecture" flag which
      # can be set to :i386 or :x86_64 to force the windows architecture.
      #
      # @param script [String] script to run
      # @param options [Hash] options hash
      # @return [Mixlib::Shellout] mixlib-shellout object
      def powershell_out(*command_args)
        script = command_args.first
        options = command_args.last.is_a?(Hash) ? command_args.last : nil

        result = run_command_with_os_architecture(script, options)

        if result.stderr.include? "A positional parameter cannot be found that accepts argument"
          raise Mixlib::ShellOut::ShellCommandFailed, "Please use single escape for special characters in powershell_out. \n #{result.stderr}"
        elsif result.stderr != ""
          raise Mixlib::ShellOut::ShellCommandFailed, result.stderr
        end
        result
      end

      # Run a command under powershell with the same API as shell_out!
      # (raises exceptions on errors)
      #
      # @param script [String] script to run
      # @param options [Hash] options hash
      # @return [Mixlib::Shellout] mixlib-shellout object
      def powershell_out!(*command_args)
        cmd = powershell_out(*command_args)
        cmd.error!
        cmd
      end

      private

      # Helper function to run shell_out and wrap it with the correct
      # flags to possibly disable WOW64 redirection (which we often need
      # because chef-client runs as a 32-bit app on 64-bit windows).
      #
      # @param script [String] script to run
      # @param options [Hash] options hash
      # @return [Mixlib::Shellout] mixlib-shellout object
      def run_command_with_os_architecture(script, options)
        options ||= {}
        options = options.dup
        arch = options.delete(:architecture)
        script_to_run = build_powershell_command(script)
        puts "gonna run\n"
        puts script_to_run

        script_to_run = build_powershell_command2(script)
        puts "not gonna run\n"
        puts script_to_run

        with_os_architecture(nil, architecture: arch) do
          shell_out(
            build_powershell_command(script),
            options
          )
        end
      end

      # Helper to build a powershell command around the script to run.
      #
      # @param script [String] script to run
      # @retrurn [String] powershell command to execute
      def build_powershell_command(script)
        flags = [
          # Hides the copyright banner at startup.
          "-NoLogo",
          # Does not present an interactive prompt to the user.
          "-NonInteractive",
          # Does not load the Windows PowerShell profile.
          "-NoProfile",
          # always set the ExecutionPolicy flag
          # see http://technet.microsoft.com/en-us/library/ee176961.aspx
          "-ExecutionPolicy Unrestricted",
          # Powershell will hang if STDIN is redirected
          # http://connect.microsoft.com/PowerShell/feedback/details/572313/powershell-exe-can-hang-if-stdin-is-redirected
          "-InputFormat None",
        ]

        # without gsub user has to add double escape for double quotes in the recipe
        "powershell.exe #{flags.join(' ')} -Command \"#{script.gsub('"', '\"')}\""
      end

      def build_powershell_command2(script)
        flags = [
          # Hides the copyright banner at startup.
          "-NoLogo",
          # Does not present an interactive prompt to the user.
          "-NonInteractive",
          # Does not load the Windows PowerShell profile.
          "-NoProfile",
          # always set the ExecutionPolicy flag
          # see http://technet.microsoft.com/en-us/library/ee176961.aspx
          "-ExecutionPolicy Unrestricted",
          # Powershell will hang if STDIN is redirected
          # http://connect.microsoft.com/PowerShell/feedback/details/572313/powershell-exe-can-hang-if-stdin-is-redirected
          "-InputFormat None",
        ]

        # without gsub user has to add double escape for double quotes in the recipe
        "powershell.exe #{flags.join(' ')} -Command \"#{script}\""
      end
    end
  end
end
