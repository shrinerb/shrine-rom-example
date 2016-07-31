require "shrine"
require "shrine/storage/file_system"
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


module Shrine::Plugins::Rom
  def self.configure(uploader, opts = {})
    uploader.opts[:rom_repository] = opts.fetch(:repository)
  end

  module AttacherClassMethods
    def find_record(record_class, record_id)
      rom_relation(record_class).where(id: record_id).one
    end

    def rom_relation(record_class)
      rom_repository(record_class).root.as(record_class)
    end

    def rom_repository(record_class)
      shrine_class.opts[:rom_repository].call(record_class)
    end
  end

  module AttacherMethods
    private

    def update(uploaded_file)
      super
      context[:record] = rom_repository.update(record.id, "#{name}_data": read)
    end

    def rom_repository
      self.class.rom_repository(record.class)
    end
  end
end

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


class ImageUploader < Shrine
  Attacher.validate do
    validate_extension_inclusion ["jpg"]
  end
end
