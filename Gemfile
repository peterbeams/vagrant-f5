source 'https://rubygems.org'

# Specify your gem's dependencies in vagrant-f5.gemspec
gemspec

group :development do
  # We depend on Vagrant for development, but we don't add it as a
  # gem dependency because we expect to be installed within the
  # Vagrant environment itself using `vagrant plugin`.
  gem "vagrant", :git => "https://github.com/mitchellh/vagrant.git"
end

group :plugins do
	gem "vagrant-f5", path: "."
end
