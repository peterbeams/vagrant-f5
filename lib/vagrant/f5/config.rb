require 'uri'

module VagrantPlugins
  module F5
    class Config < Vagrant.plugin("2", :config)
      
      attr_accessor :path
      
      def initialize      
        @path        = UNSET_VALUE        
      end

      def finalize!        
        @path        = nil if @path == UNSET_VALUE        
      end

      def validate(machine)
        errors = _detected_errors

        # Validate that the parameters are properly set
        if !path 
          errors << I18n.t("vagrant.provisioners.f5.no_path_or_inline")
        end

        # If it is not an URL, we validate the existence of a script to upload
        
          expanded_path = Pathname.new(path).expand_path(machine.env.root_path)
          if !expanded_path.file?
            errors << I18n.t("vagrant.provisioners.shell.path_invalid",
                              path: expanded_path)
          else
            data = expanded_path.read(16)
            if data && !data.valid_encoding?
              errors << I18n.t(
                "vagrant.provisioners.shell.invalid_encoding",
                actual: data.encoding.to_s,
                default: Encoding.default_external.to_s,
                path: expanded_path.to_s)
            end
          end

        { "shell provisioner" => errors }
      end

      

      def remote?
        path =~ URI.regexp(["ftp", "http", "https"])
      end
    end
  end
end
