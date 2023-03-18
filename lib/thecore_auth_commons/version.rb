# frozen string_literal: true

module ThecoreAuthCommons
  VERSION = "#{`git describe --tags --first-parent --abbrev=0`.chomp}"
end
