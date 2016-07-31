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
