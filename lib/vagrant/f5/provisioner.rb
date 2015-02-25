require "pathname"
require "tempfile"

require "vagrant/util/downloader"
require "vagrant/util/retryable"

module VagrantPlugins
  module F5
    class Provisioner < Vagrant.plugin("2", :provisioner)
      include Vagrant::Util::Retryable

      def provision
        @machine.ui.detail("Rebooting F5...")
        reboot()       
        @machine.ui.detail("Starting Provisioner...")
        provision_ssh()
      end

      def reboot()
        #run script for reboot
        @machine.communicate.tap do |comm|
          comm.execute("reboot", error_check: false)         

          #give machine 1 minute to shutdown
          sleep 60 

          #wait for machine to come back up
          comm.wait_for_ready(360)
        end        
      end

      protected

      # This handles outputting the communication data back to the UI
      def handle_comm(type, data)
        if [:stderr, :stdout].include?(type)
          # Output the data with the proper color based on the stream.
          color = type == :stdout ? :green : :red

          # Clear out the newline since we add one
          data = data.chomp
          return if data.empty?

          options = {}
          options[:color] = color if !config.keep_color

          @machine.ui.info(data.chomp, options)
        end
      end

      # This is the provision method called if SSH is what is running
      # on the remote end, which assumes a POSIX-style host.
      def provision_ssh()
        upload_path = "/tmp/vagrant-shell"
        command = "chmod +x #{upload_path} && #{upload_path}"

        with_script_file do |path|
          # Upload the script to the machine
          @machine.communicate.tap do |comm|
            # Reset upload path permissions for the current ssh user
            info = nil
            retryable(on: Vagrant::Errors::SSHNotReady, tries: 3, sleep: 2) do
              info = @machine.ssh_info
              raise Vagrant::Errors::SSHNotReady if info.nil?
            end

            user = info[:username]
            comm.sudo("chown -R #{user} #{upload_path}",
                      error_check: false)

            comm.upload(path.to_s, upload_path)

            if config.path
              @machine.ui.detail(I18n.t("vagrant.provisioners.shell.running",
                                      script: path.to_s))
            else
              @machine.ui.detail(I18n.t("vagrant.provisioners.shell.running",
                                      script: "inline script"))
            end

            # Execute it with sudo
            comm.execute(
              command,
              sudo: false,
              error_key: :ssh_bad_exit_status_muted
            ) do |type, data|
              handle_comm(type, data)
            end
          end
        end
      end

      # Quote and escape strings for shell execution, thanks to Capistrano.
      def quote_and_escape(text, quote = '"')
        "#{quote}#{text.gsub(/#{quote}/) { |m| "#{m}\\#{m}#{m}" }}#{quote}"
      end

      # This method yields the path to a script to upload and execute
      # on the remote server. This method will properly clean up the
      # script file if needed.
      def with_script_file
        ext    = nil
        script = nil

        # Just yield the path to that file...
        root_path = @machine.env.root_path
        ext    = File.extname(config.path)
        script = Pathname.new(config.path).expand_path(root_path).read
             
        script.gsub!(/\r\n?$/, "\n")
        
        # Otherwise we have an inline script, we need to Tempfile it,
        # and handle it specially...
        file = Tempfile.new(['vagrant-shell', ext])

        # Unless you set binmode, on a Windows host the shell script will
        # have CRLF line endings instead of LF line endings, causing havoc
        # when the guest executes it. This fixes [GH-1181].
        file.binmode

        begin
          file.write(script)
          file.fsync
          file.close
          yield file.path
        ensure
          file.close
          file.unlink
        end
      end
    end
  end
end
