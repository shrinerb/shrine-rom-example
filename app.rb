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

          # If params["image"] is a new raw file, upload it to cache. If the
          # file is already uploaded (e.g. retained on valiation errors or
          # directly uploaded), it proceeeds only if it's uploaded to cache,
          # for security reasons.
          #
          # In both cases this runs validations, and records that attachment
          # has changed so that it promotes the cached file to permanent
          # storage and deletes the previous attachment in Attacher#finalize.
          if r.params["image"]
            attacher.assign(r.params["image"])
            r.params["image"] = attacher.read
          end

          validation = ArticleSchema.call(r.params)
          # Adds Shrine's file validation errors that were performed on
          # Attacher#assign.
          validation.messages[:image] = attacher.errors

          if validation.success?
            attributes = validation.output
            # Even though the attachment parameter is named "image", the column
            # has to be named "image_data", because that's how it works best
            # with ORMs which implement the Active Record pattern.
            attributes[:image_data] = attributes.delete(:image)

            article = articles_repo.create(attributes)

            # Attacher#finalize will kick off a background job, and the
            # backgrounding plugin needs the created/updated record in order to
            # know whether it needs to kick off a background job, and to be
            # able to send the record class & ID, cached file, and other
            # information to background job's arguments.
            attacher.context[:record] = Article.new(article.to_h)
            # Promotes the cached file to permanent storage (either
            # synchronously or by spawning a background job), if the attachment
            # is assigned. It also deletes any previous attached files (again,
            # either synchronously or by spawning a background job).
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
          # Deletes the attached files if the record had them (either
          # synchronously or by spawning a background job).
          attacher.destroy
        end
      end
    end
  end

  def articles_repo
    Repositories::Articles.new($rom)
  end
end
