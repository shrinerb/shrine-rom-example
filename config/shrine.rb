require "shrine"
require "shrine/storage/file_system"
require "./config/shrine-rom"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("uploads/cache"),
  store: Shrine::Storage::FileSystem.new("uploads/store"),
}

Shrine.plugin :rack_file
Shrine.plugin :logging
Shrine.plugin :determine_mime_type
Shrine.plugin :validation_helpers
Shrine.plugin :backgrounding

Shrine.plugin Shrine::Plugins::Rom,
  repository: ->(model) { Object.const_get("Repositories::#{model}s").new($rom) }

# Imitate backgrund jobs, to fully test the shrine-rom plugin
Shrine::Attacher.promote { |data| self.class.promote(data) }
Shrine::Attacher.delete { |data| self.class.delete(data) }
