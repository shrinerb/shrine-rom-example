require "dry-types"
require "dry-validation"

module Types
  include Dry::Types.module
end

class Article < Dry::Types::Struct
  attribute :id,         Types::Int
  attribute :title,      Types::String
  attribute :body,       Types::String
  attribute :image_data, Types::String

  attr_writer :image_data # for Shrine
end

ArticleSchema = Dry::Validation.Form do
  required(:title).filled
  required(:body).filled
  required(:image).filled
end

module Presenters
  class Article
    def initialize(article)
      @article = article
    end

    def to_h
      image = ImageUploader.uploaded_file(@article.image_data)

      {
        id:    @article.id,
        title: @article.title,
        body:  @article.body,
        image: {
          url:      image.url,
          metadata: image.metadata,
        },
      }
    end
  end
end

class ImageUploader < Shrine
  Attacher.validate do
    validate_extension_inclusion ["jpg"]
  end
end
