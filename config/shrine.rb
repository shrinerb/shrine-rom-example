require "shrine"
require "shrine/storage/file_system"
require "./config/shrine-rom"
require "sucker_punch"
require "sucker_punch/testing/inline" # synchronous jobs

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

Shrine::Attacher.promote { |data| PromoteJob.perform_async(data) }
Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }

class PromoteJob
  include SuckerPunch::Job
  def perform(data)
    Shrine::Attacher.promote(data)
  end
end

class DeleteJob
  include SuckerPunch::Job
  def perform(data)
    Shrine::Attacher.delete(data)
  end
end
