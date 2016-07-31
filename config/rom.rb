require "rom-sql"
require "rom-repository"

$rom = ROM.container(:sql, "sqlite::memory") do |conf|
  conf.default.create_table(:articles) do
    primary_key :id
    column :title, :string
    column :body, :text
    column :image_data, :text
  end
end

module Relations
  class Articles < ROM::Relation[:sql]
    schema(infer: true)
  end
end

module Repositories
  class Articles < ROM::Repository[:articles]
    commands :create, update: :by_pk, delete: :by_pk

    def by_id(id)
      articles.where(id: id).as(Article).one
    end
  end
end
