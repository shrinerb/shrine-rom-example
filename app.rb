require "./config/rom"
require "./config/shrine"
require "./config/objects"

require "roda"

class App < Roda
  plugin :all_verbs
  plugin :json, serializer: ->(object) { JSON.pretty_generate(object) }

  route do |r|
    r.on "articles" do
      r.is do
        r.post do
          attacher = ImageUploader::Attacher.new(Article.new, :image)

          if r.params["image"]
            attacher.assign(r.params["image"])
            r.params["image"] = attacher.read
          end

          validation = ArticleSchema.call(r.params)
          validation.messages[:image] = attacher.errors

          if validation.success?
            attributes = validation.output
            attributes[:image_data] = attributes.delete(:image)

            article = articles_repo.create(attributes)

            attacher.context[:record] = Article.new(article.to_h)
            attacher.finalize if attacher.attached?

            Presenters::Article.new(article).to_h
          else
            response.status = 400
            validation.messages
          end
        end
      end

      r.is ":id" do |id|
        r.get do
          article = articles_repo.by_id(id)

          Presenters::Article.new(article).to_h
        end

        r.put do
          article = articles_repo.by_id(id)
          attacher = ImageUploader::Attacher.new(article, :image)

          if r.params["image"]
            attacher.assign(r.params["image"])
            r.params["image"] = attacher.read
          end

          validation = ArticleSchema.call(article.to_h.merge(r.params))
          validation.messages[:image] = attacher.errors

          if validation.success?
            attributes = validation.output
            attributes[:image_data] = attributes.delete(:image)

            article = articles_repo.update(article.id, attributes)

            attacher.context[:record] = Article.new(article.to_h)
            attacher.finalize if attacher.attached?

            Presenters::Article.new(article).to_h
          else
            response.status = 400
            validation.messages
          end
        end

        r.delete do
          article = articles_repo.by_id(id)
          articles_repo.delete(article.id)

          attacher = ImageUploader::Attacher.new(article, :image)
          attacher.destroy
        end
      end
    end
  end

  def articles_repo
    Repositories::Articles.new($rom)
  end
end
