# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "webyast-kerberos"
  s.version = "0.3.3"
  s.authors = ["WebYaST team"]
  s.summary = "Webyast module for configuring kerberos settings"
  s.email = "yast-devel@opensuse.org"
  s.licenses = ['GPL-2.0']

  ignore_files = ["package/rubygem-webyast-kerberos.changes", "package/rubygem-webyast-kerberos.spec"]
  s.files         = `git ls-files`.split("\n").delete_if{|f| f.match(/^locale\/.*\.po$/) || f.match(/.gitignore$/) || ignore_files.include?(f)}.concat(Dir.glob("locale/**/*.mo")) rescue []

  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n") rescue []
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) } rescue []
  s.require_paths = ["lib"]
end
