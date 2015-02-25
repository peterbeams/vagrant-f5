require "vagrant"
require_relative "communicator"

module VagrantPlugins
  module F5
    class Plugin < Vagrant.plugin("2")
      name "f5 communicator"
      description <<-DESC
      This plugin allows Vagrant to communicate with remote machines using
      SSH as the underlying protocol for F5 BIG-IP machines, 
      powered internally by Ruby's net-ssh library.
      DESC

      communicator("f5") do     
        Communicator
      end

      config(:f5, :provisioner) do
        require File.expand_path("../config", __FILE__)
        Config
      end

      provisioner(:f5) do
        require File.expand_path("../provisioner", __FILE__)
        Provisioner
      end
    end
  end
end
