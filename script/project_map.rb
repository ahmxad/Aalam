#!/usr/bin/env ruby
# frozen_string_literal: true

# Writes a short, backend-focused Markdown map of the project (docs/PROJECT_MAP.md):
# Rails and Ruby versions, the database adapter and settings, the objects in db/schema.rb,
# route names, and the list of backend files.
#
#   ruby script/project_map.rb               writes docs/PROJECT_MAP.md
#   ruby script/project_map.rb --out FILE    writes another file
#   ruby script/project_map.rb --no-routes   skips `bin/rails routes` (faster)
#
# Files are listed by name only and their contents are never copied.
# Passwords and database URLs are never printed.

require "fileutils"
require "open3"
require "optparse"
require "pathname"
require "yaml"

module ProjectMap
  ROOT = File.expand_path("..", __dir__)
  DEFAULT_OUTPUT = "docs/PROJECT_MAP.md"

  # The only places listed in the "Files" section
  TREE_ROOTS = %w[
    app/assets/tailwind
    app/controllers
    app/models
    app/views
    config/routes.rb
    db/migrate
    db/schema.rb
  ].freeze

  # Database settings worth showing. The adapter has its own line, and passwords are never shown.
  DB_SETTINGS = %w[
    host port username database url pool max_connections timeout encoding migrations_paths schema_search_path
  ].freeze

  ADAPTER_GEMS = {
    "postgresql" => "pg",
    "mysql2" => "mysql2",
    "trilogy" => "trilogy",
    "sqlite3" => "sqlite3"
  }.freeze

  # Routes that Rails and its engines add by themselves, which are not part of the app
  INTERNAL_CONTROLLERS = %r{\A(active_storage|action_mailbox|turbo)/|\Arails/(conductor|mailers|info|welcome|rescues)}

  # ---------------------------------------------------------------- reading project files

  def self.read(path)
    full = File.join(ROOT, path)
    File.file?(full) ? File.read(full).scrub : nil
  end

  def self.project_name
    read("config/application.rb").to_s[/^module\s+(\w+)/, 1] || File.basename(ROOT)
  end

  # ---------------------------------------------------------------- versions

  def self.ruby_version
    version = read(".ruby-version").to_s[/\d+\.\d+(?:\.\d+)?/]
    return "#{version} (.ruby-version)" if version

    %w[mise.toml .mise.toml .tool-versions].each do |file|
      version = read(file).to_s[/^\s*ruby\s*=?\s*["']?(\d[\w.]*)/, 1]
      return "#{version} (#{file})" if version
    end

    version = read("Gemfile").to_s[/^\s*ruby\s+["']([^"']+)["']/, 1]
    return "#{version} (Gemfile)" if version

    version = read("Gemfile.lock").to_s[/^RUBY VERSION\s*\n\s*ruby\s+(\d[\d.]*)/, 1]
    return "#{version} (Gemfile.lock)" if version

    "#{RUBY_VERSION} (the Ruby that ran this script)"
  end

  def self.gem_version(name)
    read("Gemfile.lock").to_s[/^ {4}#{Regexp.escape(name)} \(([^)]+)\)/, 1]
  end

  def self.rails_version
    locked = gem_version("rails")
    return locked if locked

    declared = read("Gemfile").to_s[/^\s*gem\s+["']rails["'],\s*["']([^"']+)["']/, 1]
    declared ? "#{declared} (declared in Gemfile)" : "unknown"
  end

  # ---------------------------------------------------------------- database settings

  # ERB in database.yml is never run: ENV lookups become env(NAME), anything else becomes erb
  def self.env_token(code)
    name = code[/ENV(?:\.fetch)?\s*[\[(]\s*["']([A-Za-z0-9_]+)["']/, 1]
    name ? "env(#{name})" : "erb"
  end

  def self.load_database_config
    text = read("config/database.yml")
    return nil unless text

    plain = text.gsub(/<%#.*?%>/m, "")
                .gsub(/<%(?!=).*?%>/m, "")
                .gsub(/<%=(.*?)%>/m) { env_token(Regexp.last_match(1)) }
    data = YAML.safe_load(plain, aliases: true)
    data.is_a?(Hash) ? data : nil
  rescue Psych::Exception
    nil
  end

  # Returns the shared settings and a list of [label, settings, baseline] for each environment.
  # In a multi-database environment the first database is the baseline of the others.
  def self.db_entries(config)
    default = %w[default defaults].map { |key| config[key] }.find { |value| value.is_a?(Hash) } || {}
    entries = []

    config.each do |env, settings|
      next if %w[default defaults].include?(env) || !settings.is_a?(Hash)

      if settings.values.any?(Hash)
        first = nil
        settings.each do |name, database|
          next unless database.is_a?(Hash)

          entries << [ "#{env} #{name}", database, first || default ]
          first ||= database
        end
      else
        entries << [ env, settings, default ]
      end
    end

    [ default, entries ]
  end

  # Only the settings that differ from the baseline. A url is never printed, only the name of its variable.
  def self.setting_pairs(settings, baseline = {})
    DB_SETTINGS.filter_map do |key|
      next unless settings.key?(key) && settings[key] != baseline[key]

      value = settings[key]
      value = (value.to_s.match?(/\Aenv\(\w+\)\z/) ? value : "set") if key == "url"
      "#{key}=#{value}"
    end
  end

  # The tables are created by the user that runs the migrations: the development user
  def self.table_owner(default, entries)
    development = entries.find { |label, _settings, _baseline| label.start_with?("development") }
    return development[1]["username"] || "(OS user)" if development

    entries.filter_map { |_label, settings, _baseline| settings["username"] }.first || default["username"] || "(OS user)"
  end

  def self.adapter_line(adapter)
    return "- Adapter: unknown" unless adapter

    gem = ADAPTER_GEMS[adapter]
    version = gem && gem_version(gem)
    version ? "- Adapter: `#{adapter}` (gem `#{gem}` #{version})" : "- Adapter: `#{adapter}`"
  end

  # One line for every group of objects that share a schema and a type
  def self.table_lines(schema, adapter, owner)
    default_schema = adapter == "postgresql" ? "public" : "-"
    objects = schema.scan(/^\s*create_(table|view)\s+"([^"]+)"/).map do |type, full_name|
      schema_name, name = full_name.include?(".") ? full_name.split(".", 2) : [ default_schema, full_name ]
      [ schema_name, type, name ]
    end

    objects.group_by { |schema_name, type, _name| [ schema_name, type ] }.map do |(schema_name, type), group|
      names = group.map { |_schema_name, _type, name| name }.join(", ")
      "- schema `#{schema_name}` · #{type} · owner `#{owner}`: `#{names}`"
    end
  end

  def self.database_lines(schema)
    config = load_database_config
    default, entries = config ? db_entries(config) : [ {}, [] ]
    adapter = ([ default ] + entries.map { |_label, settings, _baseline| settings }).filter_map { |settings| settings["adapter"] }.first

    lines = [ "## Database", "", adapter_line(adapter) ]
    lines << "- config/database.yml could not be read" unless config

    shared = setting_pairs(default)
    joined = shared.join(", ")
    lines << "- Shared settings: `#{joined}`" unless shared.empty?

    entries.each do |label, settings, baseline|
      pairs = setting_pairs(settings, baseline)
      other = settings["adapter"]
      pairs.unshift("adapter=#{other}") if other && other != adapter
      joined = pairs.join(", ")
      text = pairs.empty? ? "same as above" : "`#{joined}`"
      lines << "- #{label}: #{text}"
    end

    version = schema[/define\(version:\s*([\d_]+)\)/, 1]
    extensions = schema.scan(/^\s*enable_extension\s+"([^"]+)"/).flatten.map { |name| name.delete_prefix("pg_catalog.") }
    facts = []
    facts << "schema version `#{version}`" if version
    facts << "extensions `#{extensions.join(', ')}`" unless extensions.empty?
    lines << "- #{facts.join(' · ')}" unless facts.empty?

    others = Dir.glob("db/*_schema.rb", base: ROOT).sort
    names = others.map { |file| "`#{file}`" }.join(", ")
    lines << "- Other schema files (not listed below): #{names}" unless others.empty?

    objects = table_lines(schema, adapter, table_owner(default, entries))
    lines.push("", objects.empty? ? "_No tables found in db/schema.rb._" : "Objects in `db/schema.rb`:", "")
    lines.concat(objects)
    lines << ""
  end

  # ---------------------------------------------------------------- route names

  # Returns [[name, controller#action], ...] and nil, or nil and the reason it failed
  def self.route_pairs
    out, err, status = Open3.capture3({ "RAILS_ENV" => "development" }, "bin/rails", "routes", "--expanded", chdir: ROOT)
    return [ nil, err.lines.first.to_s.strip ] unless status.success?

    pairs = out.split(/^--\[ Route \d+ \].*$/).filter_map do |block|
      fields = block.lines.filter_map do |line|
        key, value = line.split("|", 2)
        [ key.strip, value.strip ] if value
      end.to_h

      name = fields["Prefix"].to_s
      controller = fields["Controller#Action"].to_s
      [ name, controller ] unless name.empty? || controller.empty? || controller.match?(INTERNAL_CONTROLLERS)
    end

    [ pairs.uniq(&:first), nil ]
  rescue SystemCallError => error
    [ nil, error.message ]
  end

  def self.routes_lines(enabled)
    lines = [ "## Route names", "" ]
    return lines.push("_Skipped (--no-routes)._", "") unless enabled

    pairs, problem = route_pairs
    return lines.push("_Could not run `bin/rails routes`: #{problem}_", "") if problem

    admin, site = pairs.partition { |_name, controller| controller.start_with?("admin/") }
    lines << "- Public: `#{site.map(&:first).join(', ')}`" unless site.empty?
    lines << "- Admin: `#{admin.map(&:first).join(', ')}`" unless admin.empty?
    lines << ""
  end

  # ---------------------------------------------------------------- file list

  def self.keep(paths)
    paths.uniq
         .reject { |path| File.basename(path) == ".keep" }
         .select { |path| File.file?(File.join(ROOT, path)) }
         .sort
  end

  # Files that git knows (tracked, or new and not ignored)
  def self.project_files
    out, _err, status = Open3.capture3("git", "ls-files", "--cached", "--others", "--exclude-standard", "-z", chdir: ROOT)
    paths = status.success? ? out.force_encoding(Encoding::UTF_8).split("\0") : Dir.glob("**/*", base: ROOT)
    keep(paths)
  rescue SystemCallError
    keep(Dir.glob("**/*", base: ROOT))
  end

  def self.render_tree(paths, depth)
    indent = "  " * depth
    direct, nested = paths.partition { |path| !path.include?("/") }
    lines = direct.sort.map { |name| "#{indent}#{name}" }

    nested.group_by { |path| path.split("/", 2).first }.sort.each do |dir, group|
      lines << "#{indent}#{dir}/"
      lines.concat(render_tree(group.map { |path| path.split("/", 2).last }, depth + 1))
    end
    lines
  end

  def self.tree_lines(files)
    TREE_ROOTS.flat_map do |root|
      if root.end_with?(".rb")
        files.include?(root) ? [ root ] : []
      else
        inside = files.select { |path| path.start_with?("#{root}/") }.map { |path| path.delete_prefix("#{root}/") }
        inside.empty? ? [] : [ "#{root}/", *render_tree(inside, 1) ]
      end
    end
  end

  def self.files_lines(files)
    [ "## Files", "", "```text", *tree_lines(files), "```", "" ]
  end

  # ---------------------------------------------------------------- the document

  def self.document(options)
    schema = read("db/schema.rb").to_s
    date = Time.now.strftime("%Y-%m-%d")

    lines = [ "# #{project_name} — backend map", "", "_Generated by `script/project_map.rb` on #{date}._", "" ]
    lines.push("## Stack", "", "- Rails #{rails_version}", "- Ruby #{ruby_version}", "")
    lines.concat(database_lines(schema))
    lines.concat(routes_lines(options[:routes]))
    lines.concat(files_lines(project_files))
    lines.join("\n")
  end

  def self.run(argv)
    options = { out: DEFAULT_OUTPUT, routes: true }
    OptionParser.new do |parser|
      parser.banner = "Usage: ruby script/project_map.rb [options]"
      parser.on("--out FILE", "Output file (default: #{DEFAULT_OUTPUT})") { |value| options[:out] = value }
      parser.on("--[no-]routes", "Run bin/rails routes for the route names (default: yes)") { |value| options[:routes] = value }
    end.parse!(argv)

    target = File.expand_path(options[:out], ROOT)
    FileUtils.mkdir_p(File.dirname(target))

    body = "#{document(options).rstrip}\n"
    File.write(target, body)

    relative = Pathname.new(target).relative_path_from(Pathname.new(ROOT))
    puts "Wrote #{relative} (#{body.lines.size} lines, about #{body.split.size} words)."
  end
end

ProjectMap.run(ARGV) if $PROGRAM_NAME == __FILE__
